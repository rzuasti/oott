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

# Print the id of the first connected Android device, or nothing if none is up.
# `flutter run -d <x>` matches a device by id/name, never by platform, so the
# literal "android" is not a usable target; we must resolve the concrete id
# (e.g. "emulator-5554") from flutter's own machine-readable device list.
android_device_id() {
  flutter devices --machine 2>/dev/null | python3 -c '
import json, sys
try:
    devices = json.load(sys.stdin)
except ValueError:
    devices = []
for d in devices:
    if str(d.get("targetPlatform", "")).startswith("android"):
        print(d["id"])
        break
'
}

# Block until the Android OS on the given device has finished booting. The
# device shows up in `flutter devices` as soon as adb connects, but installing
# before boot completes fails with "device is still booting", so we poll the
# sys.boot_completed property (adb shell emits CRLF, hence the trailing-\r trim).
wait_for_boot() {
  local serial="$1"
  adb -s "$serial" wait-for-device
  until [ "$(adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do
    sleep 2
  done
}

# Boot the emulator in the background if no Android device is connected yet.
if [ -z "$(android_device_id)" ]; then
  echo "No Android device detected, booting the emulator..."
  "$SCRIPT_DIR/run_android.sh" -no-snapshot-save &

  echo "Waiting for the emulator to come online..."
  until [ -n "$(android_device_id)" ]; do
    sleep 2
  done
fi

device_id="$(android_device_id)"
echo "Waiting for '$device_id' to finish booting..."
wait_for_boot "$device_id"

echo "Launching OOTT on '$device_id'..."
exec flutter run -d "$device_id" "$@"
