{pkgs}:
pkgs.rustPlatform.buildRustPackage rec {
  pname = "oott";
  version = "0.0.1";
  src = ./..;
  cargoLock = {
    lockFile = ./../Cargo.lock;
  };

  nativeBuildInputs = [pkgs.pkg-config];
  PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
}
