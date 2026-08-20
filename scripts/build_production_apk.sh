#!/usr/bin/env bash
# Build a production Android APK (release, obfuscated).
#
# Usage:
#   ./scripts/build_production_apk.sh
#   ./scripts/build_production_apk.sh --split-per-abi
#
# Output:
#   build/app/outputs/flutter-apk/*.apk
#   dist/android/*.apk
set -euo pipefail

# shellcheck source=scripts/_common.sh
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

require_flutter

SPLIT_PER_ABI=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --split-per-abi)
      SPLIT_PER_ABI=1
      shift
      ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      exit 1
      ;;
  esac
done

prepare_dist
mkdir -p "$DIST_DIR/android/symbols"
pub_get

BUILD_ARGS=(
  build apk
  --release
  --tree-shake-icons
  --obfuscate
  --split-debug-info="$DIST_DIR/android/symbols"
)
if [[ "$SPLIT_PER_ABI" -eq 1 ]]; then
  BUILD_ARGS+=(--split-per-abi)
fi

echo "==> flutter ${BUILD_ARGS[*]}"
flutter "${BUILD_ARGS[@]}"

APK_DIR="$ROOT/build/app/outputs/flutter-apk"
if [[ ! -d "$APK_DIR" ]]; then
  echo "error: expected APK output directory missing: $APK_DIR" >&2
  exit 1
fi

VERSION="$(app_version | tr '+' '_')"
COPIED=()
shopt -s nullglob
for apk in "$APK_DIR"/*.apk; do
  base="$(basename "$apk")"
  dest="$DIST_DIR/android/SafariCard_${VERSION}_prod_${base}"
  cp -f "$apk" "$dest"
  COPIED+=("$dest")
done
shopt -u nullglob

if [[ ${#COPIED[@]} -eq 0 ]]; then
  echo "error: no APK files found in $APK_DIR" >&2
  exit 1
fi

echo ""
echo "Production APK(s) built:"
for f in "${COPIED[@]}"; do
  ls -lh "$f"
done

stamp_note "$DIST_DIR/android"
echo ""
echo "Note: release currently uses the debug signingConfig in android/app/build.gradle."
echo "Configure a release keystore before distributing to production users."
