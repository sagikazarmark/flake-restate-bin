# flake-restate-bin

Nix flake for prebuilt [Restate](https://restate.dev) binaries, fetched from
[GitHub releases](https://github.com/restatedev/restate/releases).

The `restate-bin` package contains:

- `restate` (CLI, with bash/fish/zsh completions)
- `restatectl`
- `restate-server`

Supported systems: `aarch64-darwin`, `aarch64-linux`, `x86_64-linux`
(`x86_64-darwin` works through the overlay on nixpkgs 26.05 and earlier).

## Usage

```shell
nix run github:sagikazarmark/flake-restate-bin -- --help
nix shell github:sagikazarmark/flake-restate-bin
```

As a flake input:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    restate-bin = {
      url = "github:sagikazarmark/flake-restate-bin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, restate-bin, ... }: {
    # restate-bin.packages.${system}.restate-bin
    # or the overlay: restate-bin.overlays.default
  };
}
```

### License

Restate is licensed under the [Business Source License 1.1](https://github.com/restatedev/restate/blob/main/LICENSE),
which nixpkgs considers unfree.
The flake's `packages` output allows it automatically.
When using the overlay, allow it in your nixpkgs config:

```nix
nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "restate-bin" ];
```

## Updating

The [update workflow](.github/workflows/update.yaml) checks for new releases daily and opens a pull request.
`sources.json` holds the version and the SHA-256 checksums from the release's `sha256.sum`.

To update manually:

```shell
nix run .#update          # latest release
nix run .#update -- v1.8.0  # specific tag
```

`flake.lock` is updated weekly by a [separate workflow](.github/workflows/update-flake-lock.yaml),
and GitHub Actions versions by [Dependabot](.github/dependabot.yml).

### Auto-merge

Both update workflows enable auto-merge (squash) on the pull requests they open.
This needs some repository setup to be safe:

1. Add an `UPDATE_TOKEN` repository secret (a fine-grained PAT or GitHub App token with contents and pull request write access).
   Pull requests opened with the default `GITHUB_TOKEN` don't trigger CI.
2. Enable **Allow auto-merge** in the repository settings.
3. Protect `main` (branch protection or a ruleset) and require the `Build (ubuntu-latest)` and `Build (macos-latest)` status checks.
   **Without required checks, the pull request is merged immediately, without waiting for CI.**
