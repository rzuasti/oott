#!/usr/bin/env bash
#
# Run the OOTT front-end on the Android emulator.
#
# Boots the emulator first (via run_android.sh) if it isn't already running,
# then launches the Flutter app on it. Any extra arguments are forwarded to
# `flutter run`.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v flutter >/dev/null 2>&1; then
  echo "error: 'flutter' not found on PATH." >&2
  echo "       Enter the dev shell first (e.g. 'nix develop')." >&2
  exit 1
fi

# Boot the emulator in the background if no Android device is connected yet.
if ! flutter devices 2>/dev/null | grep -qi "android"; then
  echo "No Android device detected, booting the emulator..."
  "$SCRIPT_DIR/run_android.sh" -no-snapshot-save &

  echo "Waiting for the emulator to come online..."
  until flutter devices 2>/dev/null | grep -qi "android"; do
    sleep 2
  done
fi

exec flutter run -d android "$@"
