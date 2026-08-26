#!/usr/bin/env bash
# Build a release iOS app / IPA for SafariTap.
#
# Usage:
#   ./scripts/build_ios.sh                 # flutter build ipa (requires signing)
#   ./scripts/build_ios.sh --no-codesign   # unsigned ios build (CI / archive later)
#   ./scripts/build_ios.sh --ipa           # force IPA path (default)
#   ./scripts/build_ios.sh --ios-only      # flutter build ios --release
#
# Output:
#   build/ios/ipa/*.ipa   (signed IPA)
#   build/ios/iphoneos/Runner.app  (unsigned / ios-only)
#   dist/ios/*            (copy when IPA exists)
#
# Requires: macOS, Xcode, CocoaPods, valid Apple signing for IPA.
set -euo pipefail

# shellcheck source=scripts/_common.sh
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

require_flutter
require_macos

MODE="ipa"
NO_CODESIGN=0
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-codesign)
      NO_CODESIGN=1
      MODE="ios"
      shift
      ;;
    --ios-only)
      MODE="ios"
      shift
      ;;
    --ipa)
      MODE="ipa"
      shift
      ;;
    --obfuscate)
      EXTRA_ARGS+=(--obfuscate --split-debug-info="$DIST_DIR/ios/symbols")
      shift
      ;;
    -h|--help)
      sed -n '2,16p' "$0"
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

if [[ -d "$ROOT/ios" ]]; then
  echo "==> pod install (ios)"
  (
    cd "$ROOT/ios"
    if command -v pod >/dev/null 2>&1; then
      pod install --repo-update || pod install
    else
      echo "warning: CocoaPods (pod) not found; continuing without pod install"
    fi
  )
fi

if [[ "$MODE" == "ipa" ]]; then
  echo "==> flutter build ipa --release --tree-shake-icons ${EXTRA_ARGS[*]:-}"
  flutter build ipa --release --tree-shake-icons "${EXTRA_ARGS[@]}"

  IPA_DIR="$ROOT/build/ios/ipa"
  shopt -s nullglob
  IPAS=("$IPA_DIR"/*.ipa)
  shopt -u nullglob

  if [[ ${#IPAS[@]} -eq 0 ]]; then
    echo "error: no IPA produced in $IPA_DIR" >&2
    echo "Tip: open ios/Runner.xcworkspace in Xcode, set signing team, then retry." >&2
    echo "Or run: ./scripts/build_ios.sh --no-codesign" >&2
    exit 1
  fi

  VERSION="$(app_version | tr '+' '_')"
  for ipa in "${IPAS[@]}"; do
    dest="$DIST_DIR/ios/SafariTap_${VERSION}_$(basename "$ipa")"
    cp -f "$ipa" "$dest"
    ls -lh "$dest"
  done
  stamp_note "$DIST_DIR/ios"
else
  BUILD_ARGS=(build ios --release --tree-shake-icons)
  if [[ "$NO_CODESIGN" -eq 1 ]]; then
    BUILD_ARGS+=(--no-codesign)
  fi
  BUILD_ARGS+=("${EXTRA_ARGS[@]}")

  echo "==> flutter ${BUILD_ARGS[*]}"
  flutter "${BUILD_ARGS[@]}"

  stamp_note "$ROOT/build/ios/iphoneos"
  echo ""
  echo "Unsigned/ios-only build ready under build/ios/."
  echo "Archive & export an IPA from Xcode, or re-run without --no-codesign once signing is configured."
fi
