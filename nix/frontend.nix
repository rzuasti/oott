{flutter}: let
  # Single source of truth: extract the version from frontend/pubspec.yaml.
  # Nix has no YAML parser, so split into lines and read the `version:` line.
  # (Matching the whole file with a single regex is avoided on purpose: nested
  # quantifiers over the full text trigger catastrophic backtracking in Nix's
  # regex engine.)
  lines = builtins.filter builtins.isString (builtins.split "\n" (builtins.readFile ./../frontend/pubspec.yaml));
  versionLine = builtins.head (builtins.filter (line: builtins.match "version:.*" line != null) lines);
  version = builtins.head (builtins.match "version: *([^ ]+) *" versionLine);
in
  flutter.buildFlutterApplication {
    pname = "oott-frontend";
    inherit version;
    src = ./../frontend;

    # Fetches pub dependencies from the committed pubspec.lock (all hosted, no git deps).
    autoPubspecLock = ./../frontend/pubspec.lock;

    # Build the web bundle (the backend serves these assets).
    targetFlutterPlatform = "web";
  }
