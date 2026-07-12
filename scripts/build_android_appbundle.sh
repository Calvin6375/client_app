#!/usr/bin/env bash
# Build a release Android App Bundle (AAB) for Play Store upload.
#
# Usage:
#   ./scripts/build_android_appbundle.sh
#   ./scripts/build_android_appbundle.sh --obfuscate
#
# Output:
#   build/app/outputs/bundle/release/app-release.aab
#   dist/android/*.aab  (copy)
set -euo pipefail

# shellcheck source=scripts/_common.sh
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

require_flutter

EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --obfuscate)
      EXTRA_ARGS+=(--obfuscate --split-debug-info="$DIST_DIR/android/symbols")
      shift
      ;;
    -h|--help)
      sed -n '2,11p' "$0"
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      exit 1
      ;;
  esac
done

prepare_dist
mkdir -p "$DIST_DIR/android"
pub_get

echo "==> flutter build appbundle --release --tree-shake-icons ${EXTRA_ARGS[*]:-}"
flutter build appbundle --release --tree-shake-icons "${EXTRA_ARGS[@]}"

AAB_SRC="$ROOT/build/app/outputs/bundle/release/app-release.aab"
if [[ ! -f "$AAB_SRC" ]]; then
  echo "error: expected AAB missing: $AAB_SRC" >&2
  exit 1
fi

VERSION="$(app_version | tr '+' '_')"
AAB_DEST="$DIST_DIR/android/SafariCard_${VERSION}.aab"
cp -f "$AAB_SRC" "$AAB_DEST"

ls -lh "$AAB_DEST"
stamp_note "$AAB_DEST"
echo ""
echo "Note: release currently uses the debug signingConfig in android/app/build.gradle."
echo "Configure a Play App Signing / upload keystore before shipping."
