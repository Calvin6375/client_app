#!/usr/bin/env bash
# Build all SafariCard release targets that are available on this machine.
#
# Usage:
#   ./scripts/build_all.sh
#   ./scripts/build_all.sh --skip-ios
#   ./scripts/build_all.sh --skip-android
#   ./scripts/build_all.sh --skip-web
set -euo pipefail

# shellcheck source=scripts/_common.sh
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

SKIP_IOS=0
SKIP_ANDROID=0
SKIP_WEB=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-ios) SKIP_IOS=1; shift ;;
    --skip-android) SKIP_ANDROID=1; shift ;;
    --skip-web) SKIP_WEB=1; shift ;;
    -h|--help)
      sed -n '2,10p' "$0"
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      exit 1
      ;;
  esac
done

FAILED=0

run_step() {
  local name="$1"
  shift
  echo ""
  echo "######## $name ########"
  if "$@"; then
    echo "OK: $name"
    return 0
  else
    echo "FAILED: $name" >&2
    FAILED=1
    return 1
  fi
}

if [[ "$SKIP_ANDROID" -eq 0 ]]; then
  run_step "Android APK" "$SCRIPTS_DIR/build_android_apk.sh" || true
  run_step "Android App Bundle" "$SCRIPTS_DIR/build_android_appbundle.sh" || true
fi

if [[ "$SKIP_WEB" -eq 0 ]]; then
  run_step "Web / PWA" "$SCRIPTS_DIR/build_web.sh" || true
fi

if [[ "$SKIP_IOS" -eq 0 ]]; then
  if [[ "$(uname -s)" == "Darwin" ]]; then
    # Prefer IPA; fall back to unsigned ios build if signing is not ready.
    if ! run_step "iOS IPA" "$SCRIPTS_DIR/build_ios.sh"; then
      run_step "iOS (no codesign fallback)" "$SCRIPTS_DIR/build_ios.sh" --no-codesign || true
    fi
  else
    echo "Skipping iOS (not macOS)."
  fi
fi

echo ""
if [[ "$FAILED" -ne 0 ]]; then
  echo "One or more builds failed. See output above." >&2
  exit 1
fi

stamp_note "$DIST_DIR"
echo "Artifacts are under dist/{android,ios,web}"
