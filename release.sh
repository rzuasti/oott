#!/usr/bin/env bash
#
# release.sh — cut a new OOTT release.
#
# Automates steps 1-3 of "HOWTO - Release a new OOTT version":
#   1. Bump the version (Cargo.toml, pubspec.yaml, About release date),
#      refresh lockfiles, run tests, commit & push.
#   2. Tag the release and create the GitHub release from RELEASE_NOTES.md.
#   3. Build the Docker image with Nix.
#
# Steps 4-5 (publish to Docker Hub, deploy to the test server) stay manual;
# see the HOWTO. Release notes for the version being cut must already exist in
# RELEASE_NOTES.md (see the format documented at the top of that file).

set -euo pipefail

# Always operate from the repo root (this script's directory).
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

CARGO_TOML="backend/Cargo.toml"
PUBSPEC="frontend/pubspec.yaml"
ABOUT="frontend/lib/about/about.dart"
RELEASE_NOTES="RELEASE_NOTES.md"

# --- pretty output -----------------------------------------------------------
BOLD=$'\033[1m'; DIM=$'\033[2m'; CYAN=$'\033[36m'; GREEN=$'\033[32m'
RED=$'\033[31m'; YELLOW=$'\033[33m'; RESET=$'\033[0m'

section() { printf '\n%s== %s ==%s\n' "$BOLD$CYAN" "$1" "$RESET"; }
info()    { printf '%s%s%s\n' "$GREEN" "$1" "$RESET"; }
warn()    { printf '%s%s%s\n' "$YELLOW" "$1" "$RESET"; }
die()     { printf '%s%s%s\n' "$RED" "$1" "$RESET" >&2; exit 1; }

# Echo a command (so the operator sees exactly what runs), then run it.
run() {
  printf '%s$ %s%s\n' "$DIM" "$*" "$RESET"
  "$@"
}

# Pause between major sections; abort unless the operator confirms.
confirm() {
  local reply
  printf '\n%s%s%s ' "$BOLD" "${1:-Continue?} [y/N]" "$RESET"
  read -r reply
  case "$reply" in
    y|Y|yes|YES) ;;
    *) die "Aborted." ;;
  esac
}

# --- preflight ---------------------------------------------------------------
for f in "$CARGO_TOML" "$PUBSPEC" "$ABOUT" "$RELEASE_NOTES"; do
  [ -f "$f" ] || die "Missing expected file: $f"
done
command -v gh  >/dev/null || die "gh CLI not found (needed for the GitHub release)."
command -v nix >/dev/null || die "nix not found (needed to build the Docker image)."
gh auth status >/dev/null 2>&1 || die "gh is not logged in. Run 'gh auth login' and try again (needed for the GitHub release)."

OLD_VERSION="$(sed -n 's/^version = "\(.*\)"/\1/p' "$CARGO_TOML" | head -n1)"
[ -n "$OLD_VERSION" ] || die "Could not read the current version from $CARGO_TOML."

# --- prompt for the new version ----------------------------------------------
section "OOTT release"
info "Current version: $OLD_VERSION"
printf '%sNew version (X.Y.Z): %s' "$BOLD" "$RESET"
read -r NEW_VERSION
[[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Version must be X.Y.Z (got '$NEW_VERSION')."
[ "$NEW_VERSION" != "$OLD_VERSION" ] || die "New version matches the current version."

TAG="v$NEW_VERSION"
RELEASE_DATE="$(date +"%B %-d, %Y")"   # e.g. June 2, 2026 — matches About screen

# Extract this version's section from RELEASE_NOTES.md (everything from its
# heading up to the next "## v" heading or end of file). Dots are left as regex
# wildcards; the trailing boundary makes a false match practically impossible.
NOTES_FILE="$(mktemp)"
trap 'rm -f "$NOTES_FILE"' EXIT
awk -v re="^## v${NEW_VERSION}([^0-9.]|\$)" '
  $0 ~ re        { found = 1; print; next }
  found && /^## v/ { exit }
  found          { print }
' "$RELEASE_NOTES" > "$NOTES_FILE"
[ -s "$NOTES_FILE" ] || die "No release notes for $TAG found in $RELEASE_NOTES. Add a '## $TAG — <date>' section first."

info "Releasing $TAG (was $OLD_VERSION), release date: $RELEASE_DATE"
printf '\n%s--- release notes for %s ---%s\n' "$DIM" "$TAG" "$RESET"
cat "$NOTES_FILE"
printf '%s---------------------------%s\n' "$DIM" "$RESET"
confirm "Proceed with this version and these notes?"

# === Section 1: bump the version =============================================
section "1. Bump the version"

run sed -i "s/^version = \"$OLD_VERSION\"/version = \"$NEW_VERSION\"/" "$CARGO_TOML"
run sed -i "s/^version: $OLD_VERSION/version: $NEW_VERSION/" "$PUBSPEC"
run sed -i "s/^const _releaseDate = '.*';/const _releaseDate = '$RELEASE_DATE';/" "$ABOUT"

info "Refreshing lockfiles (Cargo.lock via build.sh, pubspec.lock via flutter pub get)..."
( cd backend && run ./build.sh )
( cd frontend && run flutter pub get )

info "Checking nothing still references the old version ($OLD_VERSION)..."
if git grep -n -F "$OLD_VERSION" -- ':!*.lock' ':!'"$RELEASE_NOTES" >/dev/null 2>&1; then
  warn "Found lingering references to $OLD_VERSION:"
  git grep -n -F "$OLD_VERSION" -- ':!*.lock' ':!'"$RELEASE_NOTES" || true
  confirm "Continue despite the above references?"
else
  info "None found."
fi

info "Running the backend tests..."
( cd backend && run ./run_tests.sh )

info "Running the front-end tests..."
( cd frontend && run ./run_tests.sh )

run git add -A
run git commit -m "Release $TAG"
confirm "Push the version bump to origin/main?"
run git push origin main

# === Section 2: tag and create the GitHub release ===========================
section "2. Tag and create the GitHub release"
confirm "Create and push tag $TAG and publish the GitHub release?"

run git tag -a "$TAG" -m "OOTT $TAG"
run git push origin "$TAG"
run gh release create "$TAG" --title "OOTT $TAG" --notes-file "$NOTES_FILE"

info "Pushing $TAG triggered Codemagic to build the iOS app and upload it to TestFlight. Track the build at https://codemagic.io/apps."

# === Section 3: build the Docker image =======================================
section "3. Build the Docker image"
confirm "Build the Docker image with Nix now?"

run nix build .#dockerImage
info "Built: ./result (image 'oott:latest')."

# === Done ====================================================================
section "Done"
info "$TAG is committed, tagged, released on GitHub, and the Docker image is built."
warn "Remaining manual steps (see the HOWTO):"
printf '  4. Publish to Docker Hub (scp result -> docker load -> tag -> push).\n'
printf '  5. Deploy & validate on the internal test server.\n'
