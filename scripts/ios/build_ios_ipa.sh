#!/usr/bin/env bash
# Build a signed iOS IPA for App Store / TestFlight upload.
# Counterpart to scripts/android/build_android_appbundle.sh.
#
# Usage:
#   ./scripts/ios/build_ios_ipa.sh
#   ./scripts/ios/build_ios_ipa.sh --obfuscate
#
# Output:
#   build/ios/ipa/*.ipa
#   dist/ios/*.ipa  (copy)
#
# Requires: macOS, Xcode, CocoaPods, valid Apple signing team.
set -euo pipefail

# shellcheck source=scripts/_common.sh
source "$(cd "$(dirname "$0")" && pwd)/../_common.sh"

require_flutter
require_macos

EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
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
install_provisioning_profiles

EXPORT_PLIST="$ROOT/ios/ExportOptions.plist"
echo "==> flutter build ipa --release --tree-shake-icons --export-options-plist=ios/ExportOptions.plist ${EXTRA_ARGS[*]:-}"
flutter build ipa --release --tree-shake-icons \
  --export-options-plist="$EXPORT_PLIST" \
  "${EXTRA_ARGS[@]}"

IPA_DIR="$ROOT/build/ios/ipa"
shopt -s nullglob
IPAS=("$IPA_DIR"/*.ipa)
shopt -u nullglob

if [[ ${#IPAS[@]} -eq 0 ]]; then
  echo "error: no IPA produced in $IPA_DIR" >&2
  echo "Tip: open ios/Runner.xcworkspace in Xcode, set signing team, then retry." >&2
  echo "Or run: ./scripts/ios/build_ios.sh --no-codesign" >&2
  exit 1
fi

VERSION="$(app_version | tr '+' '_')"
for ipa in "${IPAS[@]}"; do
  dest="$DIST_DIR/ios/SafariTap_${VERSION}_$(basename "$ipa")"
  cp -f "$ipa" "$dest"
  ls -lh "$dest"
done
stamp_note "$DIST_DIR/ios"
echo ""
echo "Upload the IPA with Transporter or: xcrun altool --upload-app ..."
