# Updates sources.json from a Restate GitHub release.
#
# Usage: update [TAG]   (defaults to the latest non-prerelease)
#
# Set GITHUB_TOKEN to avoid API rate limits.

repo="restatedev/restate"
sources="${SOURCES_FILE:-sources.json}"

components=(restate-cli restatectl restate-server)
triples=(aarch64-apple-darwin x86_64-apple-darwin aarch64-unknown-linux-musl x86_64-unknown-linux-musl)

curl_args=(--fail --silent --show-error --location --retry 3)
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  curl_args+=(--header "Authorization: Bearer $GITHUB_TOKEN")
fi

tag="${1:-}"
if [[ -z "$tag" ]]; then
  tag="$(curl "${curl_args[@]}" "https://api.github.com/repos/$repo/releases/latest" | jq -r .tag_name)"
fi

echo "Fetching checksums for $repo $tag" >&2

sums="$(curl "${curl_args[@]}" "https://github.com/$repo/releases/download/$tag/sha256.sum")"

# sha256.sum lines look like: "<hex> *<file name>"
json="$(jq -Rn --arg version "${tag#v}" '
  [inputs | capture("^(?<hash>[0-9a-f]{64}) [ *](?<name>\\S+\\.tar\\.xz)$")?]
  | { version: $version, hashes: (map({ key: .name, value: .hash }) | from_entries) }
' <<<"$sums")"

missing=0
for component in "${components[@]}"; do
  for triple in "${triples[@]}"; do
    asset="$component-$triple.tar.xz"
    if ! jq -e --arg asset "$asset" '.hashes | has($asset)' <<<"$json" >/dev/null; then
      echo "error: $asset is missing from sha256.sum" >&2
      missing=1
    fi
  done
done
if [[ "$missing" -ne 0 ]]; then
  exit 1
fi

jq . <<<"$json" >"$sources"
echo "Wrote $sources (version $(jq -r .version "$sources"))" >&2
