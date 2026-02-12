{
  lib,
  pkgsBySystem,
}: let
  system = "x86_64-linux";
  pkgs = pkgsBySystem.${system};
  androidSdk = pkgs.androidenv.androidPkgs.androidsdk;

  oott-frontend = pkgs.stdenv.mkDerivation {
    name = "oott-frontend";
    version = "0.0.1";
    src = ./../frontend;
    doCheck = false;
    dontFixup = true;

    ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";

    nativeBuildInputs = [pkgs.cacert];

    buildInputs = with pkgs; [
      openssl
      flutter
      android-tools
      androidSdk
      jdk17
    ];

    buildPhase = ''
      runHook preBuild
      mkdir -p $out/web
      HOME=$out flutter build web
      cp -r build/web/* $out/web/
      runHook postBuild
    '';

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = "sha256-f9cizZBn8inksSxAgAzHOsicYpZfplm/fVfL8pPRRNU=";
    # outputHash = pkgs.lib.fakeHash;
  };

  oott-backend = pkgs.rustPlatform.buildRustPackage {
    pname = "oott-backend";
    version = "0.0.1";
    src = ./../backend;
    cargoLock = {
      lockFile = ./../backend/Cargo.lock;
    };
    nativeBuildInputs = [pkgs.pkg-config];
    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
  };
in
  pkgs.stdenv.mkDerivation {
    name = "oott";
    buildInputs = [oott-frontend oott-backend];
    src = ./../extras;
    installPhase = ''
      mkdir -p $out/bin
      mkdir -p $out/web
      cp -r ${oott-backend}/bin/* $out/bin/
      cp -r ${oott-frontend}/web/* $out/web/
    '';
  }
