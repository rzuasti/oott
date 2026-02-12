{
  lib,
  pkgs,
}: let
  oott-backend = pkgs.rustPlatform.buildRustPackage rec {
    pname = "oott-backend";
    version = "0.0.1";
    src = ./../backend;
    cargoLock = {
      lockFile = ./../backend/Cargo.lock;
    };

    nativeBuildInputs = [pkgs.pkg-config];
    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
  };

  oott-frontend = pkgs.flutter.buildFlutterApplication rec {
    pname = "oott-frontend";
    version = "0.0.1";
    src = ./../frontend;
    pubspecLock = lib.importJSON ./../frontend/pubspec.lock.json;

    buildInputs = [pkgs.yj];
    preBuild = ''
      cat $src/pubspec.lock | yj > $src/pubspec.lock.json
    '';
  };
in
  pkgs.stdenv.mkDerivation {
    name = "oott";
    buildInputs = [oott-frontend oott-backend];
    src = ./../extras;
    installPhase = ''
      mkdir -p $out/bin
      cp ${oott-backend}/bin/* $out/bin/
    '';
  }
