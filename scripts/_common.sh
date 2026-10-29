#!/usr/bin/env bash
# Shared helpers for SafariTap / pretium release build scripts.
# shellcheck shell=bash

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
DIST_DIR="$ROOT/dist"

cd "$ROOT"

require_flutter() {
  if ! command -v flutter >/dev/null 2>&1; then
    echo "error: flutter not found on PATH" >&2
    exit 1
  fi
}

require_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "error: this build requires macOS with Xcode" >&2
    exit 1
  fi
}

pub_get() {
  echo "==> flutter pub get"
  flutter pub get
}

# Xcode export only discovers profiles named <UUID>.mobileprovision.
# A friendly filename such as SafariTap_App_Store_Distribution.mobileprovision
# signs the archive, then fails at "requires a provisioning profile".
install_provisioning_profiles() {
  local dir uuid dest src
  local dirs=(
    "$HOME/Library/MobileDevice/Provisioning Profiles"
    "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
  )
  for dir in "${dirs[@]}"; do
    [[ -d "$dir" ]] || continue
    shopt -s nullglob
    for src in "$dir"/*.mobileprovision "$dir"/*.provisionprofile; do
      uuid="$(security cms -D -i "$src" 2>/dev/null | plutil -extract UUID raw -o - - 2>/dev/null || true)"
      if [[ -z "$uuid" ]]; then
        continue
      fi
      dest="$dir/${uuid}.mobileprovision"
      if [[ "$src" != "$dest" && ! -f "$dest" ]]; then
        cp -f "$src" "$dest"
        echo "==> installed provisioning profile $uuid"
      fi
      # Export looks in both locations.
      for other in "${dirs[@]}"; do
        [[ "$other" == "$dir" ]] && continue
        mkdir -p "$other"
        if [[ ! -f "$other/${uuid}.mobileprovision" ]]; then
          cp -f "$src" "$other/${uuid}.mobileprovision"
        fi
      done
    done
    shopt -u nullglob
  done
}

ios_pod_install() {
  if [[ ! -d "$ROOT/ios" ]]; then
    echo "error: ios/ directory missing" >&2
    exit 1
  fi
  echo "==> pod install (ios)"
  (
    cd "$ROOT/ios"
    if command -v pod >/dev/null 2>&1; then
      pod install --repo-update || pod install
    else
      echo "warning: CocoaPods (pod) not found; continuing without pod install"
    fi
  )
}

app_version() {
  # Reads version from pubspec.yaml (e.g. 1.0.0+13)
  local line
  line="$(grep -E '^version:' "$ROOT/pubspec.yaml" | head -1 | awk '{print $2}')"
  echo "${line:-unknown}"
}

prepare_dist() {
  mkdir -p "$DIST_DIR"
}

stamp_note() {
  local target="$1"
  local version
  version="$(app_version)"
  echo ""
  echo "========================================"
  echo "  SafariTap build complete"
  echo "  version : $version"
  echo "  output  : $target"
  echo "  time    : $(date '+%Y-%m-%d %H:%M:%S')"
  echo "========================================"
}
