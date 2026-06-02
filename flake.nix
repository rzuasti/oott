{
  description = "OOTT - An easy to setup and use network device monitoring service";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
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
    devShells = forEachSystem (system: let
      pythonEnv = pkgsBySystem.${system}.python3.withPackages (ps: [ps.anthropic]);
    in {
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
          claude-code
          clippy # Rust linter
          pythonEnv
        ];

        # fish > all
        shellHook = ''
          export PATH="${pythonEnv}/bin:$PATH"
          DEV_SHELL=oott exec fish
        '';
      };
    });

    # A Nixpkgs overlay that provides the 'oott' package and its bundled front-end.
    overlays.default = final: prev: {
      oott-frontend = final.callPackage ./nix/frontend.nix {};
      oott = final.callPackage ./nix/package.nix {};
    };

    # Package definition
    packages = forEachSystem (system: {
      oott = pkgsBySystem.${system}.oott;
      default = pkgsBySystem.${system}.oott;

      # Docker image generation
      # use via 'nix build .#dockerImage'
      dockerImage = with pkgsBySystem.${system};
        dockerTools.buildLayeredImage {
          name = "oott";
          tag = "latest";
          # oott carries its full runtime closure (incl. the bundled front-end);
          # cacert provides the trust store referenced by SSL_CERT_FILE below.
          contents = [oott cacert];
          # Ensure a writable /tmp exists (no base image provides one).
          extraCommands = "mkdir -p tmp";
          config = {
            Cmd = ["${oott}/bin/oott" "--config" "/config/oott.toml"];
            # Let openssl/native-tls (used for Pushover notifications) find the CA bundle.
            Env = ["SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt"];
          };
        };
    });

    # Modules definition
    nixosModules = import ./nix/modules {overlays = overlayList;};
  };
}
