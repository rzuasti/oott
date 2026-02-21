{
  description = "OOTT - An easy to setup and use network device monitoring service";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
    nix,
  }: let
    # System types to support.
    supportedSystems = ["x86_64-linux"];

    # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
    forEachSystem = nixpkgs.lib.genAttrs supportedSystems;

    # Package overlays to include
    overlayList = [self.overlays.default];

    # Nixpkgs instantiated for supported system types.
    pkgsBySystem = forEachSystem (system:
      import nixpkgs {
        inherit system;
        overlays = overlayList;

        # Front-end specific items
        config = {
          android_sdk.accept_license = true;
          allowUnfree = true;
        };
      });
  in rec {
    # Development shell to test the app locally
    devShells = forEachSystem (system: {
      default = pkgsBySystem.${system}.mkShell rec {
        androidSdk = pkgsBySystem.${system}.androidenv.androidPkgs.androidsdk;
        ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";

        nativeBuildInputs = with pkgsBySystem.${system}; [
          pkg-config
        ];
        buildInputs = with pkgsBySystem.${system}; [
          openssl
          rustc
          cargo
          sqlite
          flutter
          android-tools
          androidSdk
          jdk17
        ];

        # fish > all
        shellHook = ''
          exec fish
        '';
      };
    });

    # A Nixpkgs overlay that provides a 'oott' package.
    overlays.default = final: prev: {oott = final.callPackage ./nix/package.nix {};};

    # Package definition
    packages = forEachSystem (system: {
      oott = pkgsBySystem.${system}.oott;
      default = pkgsBySystem.${system}.oott;

      # Docker image generation
      # use via 'nix build .#dockerImage'
      dockerImage = with pkgsBySystem.${system};
        dockerTools.buildLayeredImage {
          # Based on the official nixos image
          fromImage = dockerTools.pullImage {
            imageName = "nixos/nix";
            imageDigest = "sha256:d5cce2440bda1f966357732c06d86cb92368069fb52dfb6b2bae8725eea488a5";
            sha256 = "sha256-4+99v7Jej0dY0zv8iJLtFiulCsw90ZnGwtjTaGu2L+c=";
            finalImageTag = "2.33.1";
            finalImageName = "nix";
          };
          name = "oott";
          tag = "latest";
          contents = [oott curl bash openssl cacert];
          config = {
            Cmd = ["${oott}/bin/oott" "--config" "/config/oott.toml"];
          };
        };
    });

    # Modules definition
    nixosModules = import ./nix/modules {overlays = overlayList;};
  };
}
