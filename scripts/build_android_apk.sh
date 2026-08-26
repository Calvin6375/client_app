#!/usr/bin/env bash
# Build a release Android APK for SafariTap.
#
# Usage:
#   ./scripts/build_android_apk.sh
#   ./scripts/build_android_apk.sh --split-per-abi
#   ./scripts/build_android_apk.sh --debug
#
# Output:
#   build/app/outputs/flutter-apk/*.apk
#   dist/android/*.apk  (copy)
set -euo pipefail

# shellcheck source=scripts/_common.sh
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

require_flutter

MODE="release"
SPLIT_PER_ABI=0
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)
      MODE="debug"
      shift
      ;;
    --split-per-abi)
      SPLIT_PER_ABI=1
      shift
      ;;
    --obfuscate)
      EXTRA_ARGS+=(--obfuscate --split-debug-info="$DIST_DIR/android/symbols")
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
mkdir -p "$DIST_DIR/android"
pub_get

BUILD_ARGS=(build apk "--$MODE" --tree-shake-icons)
if [[ "$SPLIT_PER_ABI" -eq 1 ]]; then
  BUILD_ARGS+=(--split-per-abi)
fi
BUILD_ARGS+=("${EXTRA_ARGS[@]}")

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
  dest="$DIST_DIR/android/SafariTap_${VERSION}_${base}"
  cp -f "$apk" "$dest"
  COPIED+=("$dest")
done
shopt -u nullglob

if [[ ${#COPIED[@]} -eq 0 ]]; then
  echo "error: no APK files found in $APK_DIR" >&2
  exit 1
fi

echo ""
echo "APK(s) built:"
for f in "${COPIED[@]}"; do
  ls -lh "$f"
done

stamp_note "$DIST_DIR/android"
echo ""
echo "Note: release currently uses the debug signingConfig in android/app/build.gradle."
echo "Configure a release keystore before distributing to production users."
