{
  description = "rclone-extra - packaged from the prebuilt GitHub release binary";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      lib = nixpkgs.lib;

      # repo, tag and hashes live in nix/version.json so that
      # nix/update.sh (and the update-flake workflow) only touch that file.
      info = builtins.fromJSON (builtins.readFile ./nix/version.json);

      # nix system -> asset name used by .github/workflows/build.yml
      assets = {
        x86_64-linux = "linux-amd64";
        aarch64-linux = "linux-arm64";
        armv7l-linux = "linux-arm-v7";
      };

      systems = builtins.attrNames assets;
      forAllSystems = lib.genAttrs systems;

      mkPackage = system:
        let pkgs = nixpkgs.legacyPackages.${system}; in
        pkgs.stdenvNoCC.mkDerivation {
          pname = "rclone-extra";
          version = lib.removePrefix "v" info.tag;

          src = pkgs.fetchurl {
            url = "https://github.com/${info.repo}/releases/download/${info.tag}/rclone-${assets.${system}}.zip";
            hash = info.hashes.${system};
          };

          nativeBuildInputs = [ pkgs.unzip ];
          sourceRoot = ".";

          dontConfigure = true;
          dontBuild = true;
          # Release binaries are static (CGO_ENABLED=0, netgo) and already
          # stripped, so no patchelf / strip is needed.
          dontFixup = true;

          installPhase = ''
            runHook preInstall
            install -Dm755 rclone $out/bin/rclone
            runHook postInstall
          '';

          meta = {
            description = "rclone-extra (rclone fork), prebuilt release binary";
            homepage = "https://github.com/${info.repo}";
            license = lib.licenses.mit;
            mainProgram = "rclone";
            platforms = [ system ];
            sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
          };
        };
    in
    {
      packages = forAllSystems (system: rec {
        rclone-extra = mkPackage system;
        default = rclone-extra;
      });

      apps = forAllSystems (system: rec {
        rclone-extra = {
          type = "app";
          program = "${self.packages.${system}.rclone-extra}/bin/rclone";
        };
        default = rclone-extra;
      });

      overlays.default = final: _prev: {
        rclone-extra = self.packages.${final.stdenv.hostPlatform.system}.rclone-extra;
      };
    };
}
