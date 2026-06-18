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
        # 36 = Flutter 3.41 app compileSdk/targetSdk; 33-35 cover plugin subprojects
        # which each pin their own compileSdk (e.g. package_info_plus -> 34, jni -> 35).
        platformVersions = ["33" "34" "35" "36"];
        buildToolsVersions = ["35.0.0"]; # required by Android Gradle Plugin 8.11.1
        includeEmulator = true;
        includeSystemImages = true;
        systemImageTypes = ["google_apis"];
        abiVersions = ["x86_64"];
        includeNDK = true;
        ndkVersions = ["28.2.13676358"]; # matches Flutter 3.41 flutter.ndkVersion
        cmakeVersions = ["3.22.1"]; # required by plugin native (externalNativeBuild) tasks
      };
    in {
      default = pkgsBySystem.${system}.mkShell rec {
        DEV_SHELL = "oott";
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
          nodejs_22 # push relay (push_relay/): runs npm install/test/build; bundles npm
          firebase-tools # push relay: firebase CLI for emulator (serve) and deploy
          google-cloud-sdk # push relay: gcloud for Cloud Run/IAM admin (e.g. invoker)
          clippy # Rust linter
          pythonEnv
          gh # GitHub CLI tool (for release process)
          flyctl # Fly.io CLI (deploy/fly/: test server for App Store review)
          skopeo # push the Nix-built image to the Fly registry without a Docker daemon
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

          # Enable the emulated hardware keyboard so the host keyboard is
          # forwarded into the guest. This image always exposes a (phantom)
          # hardware keyboard, which makes Gboard hide the on-screen keyboard
          # for non-password fields; without host-keyboard forwarding those
          # fields are untypable. Enforced on every entry so it also fixes a
          # pre-existing AVD, and a changed hardware config makes the emulator
          # cold-boot once so the setting takes effect.
          avdConfig="$HOME/.android/avd/$ANDROID_AVD_NAME.avd/config.ini"
          if [ -f "$avdConfig" ]; then
            if grep -q '^hw.keyboard=' "$avdConfig"; then
              sed -i 's/^hw.keyboard=.*/hw.keyboard=yes/' "$avdConfig"
            else
              printf 'hw.keyboard=yes\n' >> "$avdConfig"
            fi
          fi

          # Point the Android Gradle Plugin at the Nix-patched aapt2 shipped in
          # the SDK build-tools. AGP otherwise downloads a prebuilt aapt2 from
          # Maven that cannot run on NixOS (its ELF interpreter is missing).
          # We write this to the user-global Gradle properties because the
          # project's android/gradle.properties is version-controlled and must
          # not contain a machine-specific Nix store path. The managed block is
          # rewritten on every entry so it tracks the pinned SDK store path.
          aapt2Bin="$(ls "$ANDROID_SDK_ROOT"/build-tools/*/aapt2 2>/dev/null | sort | tail -n1)"
          if [ -n "$aapt2Bin" ]; then
            mkdir -p "$HOME/.gradle"
            gradleProps="$HOME/.gradle/gradle.properties"
            touch "$gradleProps"
            sed -i '/# >>> oott-nix >>>/,/# <<< oott-nix <<</d' "$gradleProps"
            printf '# >>> oott-nix >>>\nandroid.aapt2FromMavenOverride=%s\n# <<< oott-nix <<<\n' "$aapt2Bin" >> "$gradleProps"
          fi

          # Normalize the Android Gradle wrapper's shebang. The nixpkgs Flutter
          # SDK ships a gradlew template whose shebang is hardcoded to a specific
          # bash in the Nix store; flutter copies it verbatim into android/gradlew.
          # When that store path is later garbage-collected (or Flutter updates),
          # the interpreter vanishes and Gradle dies with a misleading
          # "ProcessException: No such file or directory". gradlew is gitignored,
          # so we rewrite it to the portable shebang on every entry.
          gradlewFile="$(git rev-parse --show-toplevel 2>/dev/null || echo .)/frontend/android/gradlew"
          if [ -f "$gradlewFile" ]; then
            sed -i '1s|^#!.*|#!/usr/bin/env sh|' "$gradlewFile"
          fi
        '';
      };
    });

    # A Nixpkgs overlay that provides the 'oott' package and its bundled front-end.
    overlays.default = final: prev: {
      oott-frontend = final.callPackage ./nix/frontend.nix {};
      oott = final.callPackage ./nix/package.nix {};
    };

    # Package definition
    packages = forEachSystem (system: let
      pkgs = pkgsBySystem.${system};

      # Startup wrapper for the Fly.io image. The backend only reads its config
      # from a TOML file, but on Fly we want the (secret) API key to come from a
      # Fly secret and the rest of the deployment knobs from plain env vars, with
      # nothing sensitive baked into the image. So we render /data/oott.toml from
      # the environment on every boot and then exec the backend against it. The
      # scanners are forced off: a cloud host has no LAN to scan, this is purely
      # an API/UI server for App Store review.
      flyEntrypoint = pkgs.writeShellApplication {
        name = "oott-fly-entrypoint";
        runtimeInputs = [pkgs.coreutils pkgs.oott];
        text = ''
          : "''${OOTT_API_KEY:?OOTT_API_KEY must be set (fly secrets set OOTT_API_KEY=...)}"
          data_dir="''${OOTT_DATA_DIR:-/data}"
          mkdir -p "$data_dir"
          cat > "$data_dir/oott.toml" <<EOF
          [database]
          path = "$data_dir/oott.db"

          [log]
          level = "''${OOTT_LOG_LEVEL:-info}"

          [notifications]
          method = "''${OOTT_NOTIFICATIONS_METHOD:-none}"

          [web_server]
          ip_address = "0.0.0.0"
          port = ''${OOTT_PORT:-8080}
          api_key = "$OOTT_API_KEY"

          [arp_scanner]
          enabled = false

          [mdns_scanner]
          enabled = false

          [ssdp_scanner]
          enabled = false

          [dhcp_scanner]
          enabled = false
          EOF
          exec oott --config "$data_dir/oott.toml"
        '';
      };
    in {
      oott = pkgs.oott;
      default = pkgs.oott;

      # Docker image generation
      # use via 'nix build .#dockerImage'
      dockerImage = with pkgs;
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

      # Fly.io deployment image (see deploy/fly/). Same backend + bundled
      # front-end as dockerImage, but its config is generated at startup from the
      # environment (flyEntrypoint) so the DB can live on a Fly volume and the
      # API key can come from a Fly secret. Build with 'nix build .#flyImage'.
      flyImage = pkgs.dockerTools.buildLayeredImage {
        name = "oott-fly";
        tag = "latest";
        contents = [flyEntrypoint pkgs.oott pkgs.cacert];
        # /tmp for the process, /data as the mountpoint for the Fly volume.
        extraCommands = "mkdir -p tmp data";
        config = {
          Cmd = ["${flyEntrypoint}/bin/oott-fly-entrypoint"];
          Env = ["SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"];
          ExposedPorts = {"8080/tcp" = {};};
        };
      };
    });

    # Modules definition
    nixosModules = import ./nix/modules {overlays = overlayList;};
  };
}
