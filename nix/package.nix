{
  pkgs,
  oott-frontend,
}: let
  # utoipa-swagger-ui's build script downloads Swagger UI from GitHub at build
  # time, which fails in Nix's network-free sandbox. Fetch the pinned archive
  # (the version bundled with utoipa-swagger-ui 9.0.2) and point the crate at it.
  swaggerUi = pkgs.fetchurl {
    url = "https://github.com/swagger-api/swagger-ui/archive/refs/tags/v5.17.14.zip";
    hash = "sha256-SBJE0IEgl7Efuu73n3HZQrFxYX+cn5UU5jrL4T5xzNw=";
  };
in
  pkgs.rustPlatform.buildRustPackage rec {
    pname = "oott";
    # Single source of truth: read the version straight from backend/Cargo.toml.
    version = (builtins.fromTOML (builtins.readFile ./../backend/Cargo.toml)).package.version;
    src = ./../backend;
    cargoLock = {
      lockFile = ./../backend/Cargo.lock;
    };

    nativeBuildInputs = [pkgs.pkg-config];
    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
    SWAGGER_UI_DOWNLOAD_URL = "file://${swaggerUi}";

    # The test suite is run separately via `backend/run_tests.sh`; this is an
    # artifact build. Skipping the check phase also avoids re-running the
    # utoipa-swagger-ui build script against its read-only OUT_DIR copy.
    doCheck = false;

    # Bundle the Flutter web build next to the binary. The backend resolves it at
    # runtime via `<exe_dir>/../share/oott/web` (see web_server::resolve_web_root).
    postInstall = ''
      mkdir -p $out/share/oott
      cp -r --no-preserve=mode ${oott-frontend} $out/share/oott/web
    '';
  }
