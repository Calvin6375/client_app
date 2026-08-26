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
