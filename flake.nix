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

      # Pin the Android SDK composition so the emulator system image is always
      # available and reproducible across machines, instead of relying on the
      # contents of the default androidPkgs bundle (which can drift over time).
      androidComposition = pkgsBySystem.${system}.androidenv.composeAndroidPackages {
        platformVersions = ["36"]; # matches Flutter 3.41 compileSdk/targetSdk
        includeEmulator = true;
        includeSystemImages = true;
        systemImageTypes = ["google_apis"];
        abiVersions = ["x86_64"];
      };
    in {
      default = pkgsBySystem.${system}.mkShell rec {
        androidSdk = androidComposition.androidsdk;
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
          gh # GitHub CLI tool (for release process)
        ];

        # fish > all
        shellHook = ''
          export PATH="${pythonEnv}/bin:$PATH"

          # Create the reproducible Android emulator (AVD) on first entry.
          # The system image is pinned by the flake, but an AVD is mutable state
          # that lives in ~/.android/avd and cannot reside in the read-only Nix
          # store, so we (re)create it here. Idempotent: a no-op once it exists.
          export ANDROID_AVD_NAME="oott_api36"
          if ! emulator -list-avds 2>/dev/null | grep -qx "$ANDROID_AVD_NAME"; then
            echo "Creating Android emulator '$ANDROID_AVD_NAME'..."
            echo no | avdmanager create avd \
              --name "$ANDROID_AVD_NAME" \
              --package "system-images;android-36;google_apis;x86_64" \
              --device pixel_6 >/dev/null 2>&1 \
              && echo "  Android emulator '$ANDROID_AVD_NAME' ready." \
              || echo "  WARNING: failed to create Android emulator '$ANDROID_AVD_NAME'."
          fi

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
