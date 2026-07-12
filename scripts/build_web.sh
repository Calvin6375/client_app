#!/usr/bin/env bash
# Production Flutter Web / PWA build for Firebase Hosting (app.truepay.live).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> flutter pub get"
flutter pub get

echo "==> flutter build web (release, tree-shake icons, offline-first PWA)"
# --pwa-strategy=offline-first keeps Flutter's generated service worker with
# hashed app-shell caching. Authenticated API hosts are not same-origin, so
# Paystack/Transak/Circle/Cloud Functions responses are never SW-cached.
# CanvasKit is selected by the current Flutter web toolchain (HTML renderer removed).
flutter build web --release \
  --pwa-strategy=offline-first \
  --tree-shake-icons \
  --no-wasm-dry-run \
  --base-href /

echo ""
echo "Build complete: $ROOT/build/web"
echo "Deploy with: firebase deploy --only hosting:app"
