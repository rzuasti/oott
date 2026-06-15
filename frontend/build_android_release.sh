#!/usr/bin/env bash
#
# Build the signed Android App Bundle (.aab) for the Google Play Store.
#
# Requires android/key.properties pointing at your upload keystore
# (see android/key.properties.example). Without it the build falls back to the
# debug signing key and Play will reject the upload.

set -e

if [ ! -f android/key.properties ]; then
    echo "error: android/key.properties not found — release would be debug-signed." >&2
    echo "       See android/key.properties.example to set up the upload keystore." >&2
    exit 1
fi

flutter build appbundle --release

echo
echo "App bundle: build/app/outputs/bundle/release/app-release.aab"
