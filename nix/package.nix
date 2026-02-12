{pkgs}: let
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
in
  pkgs.stdenv.mkDerivation {
    name = "oott";
    buildInputs = [oott-backend];
    installPhase = ''
      cp ${oott-backend}/bin/* $out/bin/
    '';
  }
