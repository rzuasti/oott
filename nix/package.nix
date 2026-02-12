# {
#   lib,
#   pkgs,
# }: let
#   oott-backend = pkgs.rustPlatform.buildRustPackage rec {
#     pname = "oott-backend";
#     version = "0.0.1";
#     src = ./../backend;
#     cargoLock = {
#       lockFile = ./../backend/Cargo.lock;
#     };
#     nativeBuildInputs = [pkgs.pkg-config];
#     PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
#   };
#   oott-frontend = pkgs.flutter.buildFlutterApplication rec {
#     pname = "oott-frontend";
#     version = "0.0.1";
#     src = ./../frontend;
#     pubspecLock = lib.importJSON ./../frontend/pubspec.lock.json;
#     # We need to create the pubspec.lock.json file beforehand, for now we do it manually before releasing a new version by
#     # cat pubspec.lock | nix run nixpkgs#yj > pubspec.lock.json
#     # buildInputs = [pkgs.yj];
#     # preBuild = ''
#     #   cat $src/pubspec.lock | yj > $src/pubspec.lock.json
#     # '';
#   };
# in
#   pkgs.stdenv.mkDerivation {
#     name = "oott";
#     buildInputs = [oott-frontend oott-backend];
#     src = ./../extras;
#     installPhase = ''
#       mkdir -p $out/bin
#       cp ${oott-backend}/bin/* $out/bin/
#     '';
#   }
{
  lib,
  pkgs,
}: let
  oott-frontend = pkgs.stdenv.mkDerivation {
    name = "oott-frontend";
    version = "0.0.1";
    src = ./../frontend;
    doCheck = false;
    dontFixup = true;

    nativeBuildInputs = [pkgs.cacert pkgs.wget];

    buildInputs = [pkgs.flutter];

    buildPhase = ''
      runHook preBuild
      mkdir -p $out/web
      # pwd
      # ls -la
      # HOME=$out flutter build web -o $out/web/ --verbose --disable-analytics
      # ls -la $out/web
      HOME=$out flutter doctor
      echo "done3"
      runHook postBuild
    '';

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = "sha256-p/tQCa0AvRHUGYiqdsILo0AEFOvXC4ZBtp8cMDv5hI0=";
    # outputHash = pkgs.lib.fakeHash;
  };
in
  pkgs.stdenv.mkDerivation {
    name = "oott";
    buildInputs = [oott-frontend];
    src = ./../extras;
    installPhase = ''
      mkdir -p $out/bin
      mkdir -p $out/web
      ls -la ${oott-frontend}
      ls -la ${oott-frontend}/web
      cp -r ${oott-frontend}/web/* $out/web/
    '';
  }
