#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/build/apfel-clip.app}"
SIGN_IDENTITY="${SIGN_IDENTITY:?set SIGN_IDENTITY to your Developer ID Application certificate name}"
ENTITLEMENTS="${ENTITLEMENTS:-}"

if [[ -x "$APP_PATH/Contents/Helpers/apfel" ]]; then
  codesign --force --timestamp --options runtime --sign "$SIGN_IDENTITY" "$APP_PATH/Contents/Helpers/apfel"
fi

if [[ -n "$ENTITLEMENTS" ]]; then
  codesign --force --timestamp --options runtime --sign "$SIGN_IDENTITY" --entitlements "$ENTITLEMENTS" "$APP_PATH"
else
  codesign --force --timestamp --options runtime --sign "$SIGN_IDENTITY" "$APP_PATH"
fi

codesign --verify --deep --strict "$APP_PATH"
spctl --assess --type execute "$APP_PATH"
