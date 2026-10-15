{
  description = "Prebuilt Restate binaries (restate, restatectl, restate-server) from GitHub releases";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      # x86_64-darwin is supported by package.nix (e.g. through the overlay on nixpkgs 26.05),
      # but nixpkgs-unstable no longer evaluates on it.
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      forAllSystems =
        f:
        lib.genAttrs systems (
          system:
          f (
            import nixpkgs {
              inherit system;
              # Restate is licensed under the BSL 1.1, which nixpkgs considers unfree.
              config.allowUnfreePredicate = pkg: lib.getName pkg == "restate-bin";
            }
          )
        );
    in
    {
      overlays.default = final: prev: {
        restate-bin = final.callPackage ./package.nix { };
      };

      packages = forAllSystems (pkgs: rec {
        restate-bin = pkgs.callPackage ./package.nix { };
        default = restate-bin;
      });

      apps = forAllSystems (pkgs: {
        update = {
          type = "app";
          program = lib.getExe (
            pkgs.writeShellApplication {
              name = "update";
              runtimeInputs = [
                pkgs.curl
                pkgs.jq
              ];
              text = builtins.readFile ./scripts/update.sh;
            }
          );
          meta.description = "Update sources.json from the latest Restate release";
        };
      });

      checks = forAllSystems (pkgs: {
        inherit (self.packages.${pkgs.stdenv.hostPlatform.system}) restate-bin;
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);
    };
}
