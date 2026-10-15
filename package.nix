{
  lib,
  stdenvNoCC,
  fetchurl,
  installShellFiles,
  sources ? lib.importJSON ./sources.json,
}:

let
  inherit (stdenvNoCC.hostPlatform) system;

  triples = {
    aarch64-darwin = "aarch64-apple-darwin";
    x86_64-darwin = "x86_64-apple-darwin";
    aarch64-linux = "aarch64-unknown-linux-musl";
    x86_64-linux = "x86_64-unknown-linux-musl";
  };

  triple = triples.${system} or (throw "restate-bin: unsupported system ${system}");

  # Release asset prefix -> binary inside the archive
  components = {
    restate-cli = "restate";
    restatectl = "restatectl";
    restate-server = "restate-server";
  };

  fetchComponent =
    component:
    let
      asset = "${component}-${triple}.tar.xz";
    in
    fetchurl {
      url = "https://github.com/restatedev/restate/releases/download/v${sources.version}/${asset}";
      sha256 = sources.hashes.${asset};
    };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "restate-bin";
  inherit (sources) version;

  srcs = map fetchComponent (lib.attrNames components);
  sourceRoot = ".";

  nativeBuildInputs = [ installShellFiles ];

  dontConfigure = true;
  dontBuild = true;
  # Stripping would invalidate the code signature of the macOS binaries
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    ${lib.concatStrings (
      lib.mapAttrsToList (component: bin: ''
        install -Dm755 ${component}-${triple}/${bin} $out/bin/${bin}
      '') components
    )}
    install -Dm644 restate-cli-${triple}/LICENSE $out/share/licenses/restate/LICENSE

    runHook postInstall
  '';

  postInstall = lib.optionalString (stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform) ''
    installShellCompletion --cmd restate \
      --bash <($out/bin/restate completions generate bash) \
      --fish <($out/bin/restate completions generate fish) \
      --zsh <($out/bin/restate completions generate zsh)
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    for bin in ${lib.concatStringsSep " " (lib.attrValues components)}; do
      echo "Checking $bin --version"
      $out/bin/$bin --version | grep -F ${lib.escapeShellArg finalAttrs.version}
    done

    runHook postInstallCheck
  '';

  passthru = {
    inherit sources;
  };

  meta = {
    description = "Restate CLI, restatectl and restate-server (prebuilt binaries from GitHub releases)";
    homepage = "https://restate.dev";
    changelog = "https://github.com/restatedev/restate/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.bsl11;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = lib.attrNames triples;
    mainProgram = "restate";
  };
})
