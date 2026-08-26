#!/usr/bin/env bash
# Build the SafariTap Flutter Web Progressive Web App (PWA).
#
# Usage:
#   ./scripts/build_web.sh
#   ./scripts/build_web.sh --deploy    # build then firebase deploy hosting:app
#
# Output:
#   build/web/
#   dist/web/   (copy of release web bundle)
#
# Production host: https://app.truepay.live
set -euo pipefail

# shellcheck source=scripts/_common.sh
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

require_flutter

DEPLOY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --deploy)
      DEPLOY=1
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
mkdir -p "$DIST_DIR/web"
pub_get

echo "==> flutter build web (release, offline-first PWA, tree-shake icons)"
# --pwa-strategy=offline-first uses Flutter's generated service worker with
# hashed app-shell caching. Auth API / Cloud Functions / Paystack / Transak /
# Circle calls are cross-origin and are not service-worker cached.
flutter build web --release \
  --pwa-strategy=offline-first \
  --tree-shake-icons \
  --no-wasm-dry-run \
  --base-href /

echo "==> copying build/web -> dist/web"
rm -rf "$DIST_DIR/web"
mkdir -p "$DIST_DIR/web"
cp -R "$ROOT/build/web/." "$DIST_DIR/web/"

stamp_note "$DIST_DIR/web"

if [[ "$DEPLOY" -eq 1 ]]; then
  if ! command -v firebase >/dev/null 2>&1; then
    echo "error: firebase CLI not found; install with: npm i -g firebase-tools" >&2
    exit 1
  fi
  echo "==> firebase deploy --only hosting:app"
  firebase deploy --only hosting:app --project truepay-72060
  echo ""
  echo "Live: https://app.truepay.live"
else
  echo ""
  echo "Deploy with:"
  echo "  ./scripts/build_web.sh --deploy"
  echo "  # or: firebase deploy --only hosting:app"
fi
