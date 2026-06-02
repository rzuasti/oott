{flutter}:
flutter.buildFlutterApplication {
  pname = "oott-frontend";
  version = "0.1.0";
  src = ./../frontend;

  # Fetches pub dependencies from the committed pubspec.lock (all hosted, no git deps).
  autoPubspecLock = ./../frontend/pubspec.lock;

  # Build the web bundle (the backend serves these assets).
  targetFlutterPlatform = "web";
}
