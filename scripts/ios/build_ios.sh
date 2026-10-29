#!/usr/bin/env bash
# Build a release iOS .app (sideload / Xcode archive later).
# Counterpart to scripts/android/build_android_apk.sh.
#
# Usage:
#   ./scripts/ios/build_ios.sh
#   ./scripts/ios/build_ios.sh --debug
#   ./scripts/ios/build_ios.sh --no-codesign
#
# Output:
#   build/ios/iphoneos/Runner.app
#
# Requires: macOS, Xcode, CocoaPods.
set -euo pipefail

# shellcheck source=scripts/_common.sh
source "$(cd "$(dirname "$0")" && pwd)/../_common.sh"

require_flutter
require_macos

MODE="release"
NO_CODESIGN=0
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)
      MODE="debug"
      shift
      ;;
    --no-codesign)
      NO_CODESIGN=1
      shift
      ;;
    --obfuscate)
      EXTRA_ARGS+=(--obfuscate --split-debug-info="$DIST_DIR/ios/symbols")
      shift
      ;;
    -h|--help)
      sed -n '2,14p' "$0"
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      exit 1
      ;;
  esac
done

prepare_dist
mkdir -p "$DIST_DIR/ios"
pub_get
ios_pod_install

BUILD_ARGS=(build ios "--$MODE" --tree-shake-icons)
if [[ "$NO_CODESIGN" -eq 1 ]]; then
  BUILD_ARGS+=(--no-codesign)
fi
BUILD_ARGS+=("${EXTRA_ARGS[@]}")

echo "==> flutter ${BUILD_ARGS[*]}"
flutter "${BUILD_ARGS[@]}"

stamp_note "$ROOT/build/ios/iphoneos"
echo ""
echo "iOS app ready under build/ios/."
echo "For App Store / TestFlight, run: ./scripts/ios/build_ios_ipa.sh"
