#!/usr/bin/env bash
#
# Launch the OOTT Android emulator created by the Nix dev shell.
#
# The AVD (named "oott_api36" by default) is auto-created from the pinned
# system image when you enter the flake dev shell. This script just boots it.
# Any extra arguments are forwarded to `emulator` (e.g. -no-window -no-audio).
set -euo pipefail

AVD_NAME="${ANDROID_AVD_NAME:-oott_api36}"

if ! command -v emulator >/dev/null 2>&1; then
  echo "error: 'emulator' not found on PATH." >&2
  echo "       Enter the dev shell first (e.g. 'nix develop')." >&2
  exit 1
fi

if ! emulator -list-avds | grep -qx "$AVD_NAME"; then
  echo "error: Android emulator '$AVD_NAME' not found." >&2
  echo "       Re-enter the dev shell to have it created automatically." >&2
  exit 1
fi

exec emulator -avd "$AVD_NAME" "$@"
