{
  pkgs,
  buildRustPackage,
  pname,
  version,
}:
buildRustPackage rec {
  inherit pname;
  inherit version;
  src = ./.;
  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  nativeBuildInputs = [pkgs.pkg-config];
  PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
}
