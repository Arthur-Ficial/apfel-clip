#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="apfel-clip"
APP_BUNDLE="$ROOT_DIR/build/${APP_NAME}.app"
VERSION="$(tr -d '\n' < "$ROOT_DIR/.version")"
ICON_SOURCE="$ROOT_DIR/Resources/AppIcon.icns"
ICON_SCRIPT="$ROOT_DIR/scripts/generate-icon.swift"

resolve_helper() {
  if [[ -n "${APFEL_HELPER_PATH:-}" && -x "${APFEL_HELPER_PATH}" ]]; then
    print -- "${APFEL_HELPER_PATH}"
    return 0
  fi

  if command -v apfel >/dev/null 2>&1; then
    command -v apfel
    return 0
  fi

  return 1
}

print "==> Building ${APP_NAME} ${VERSION}"
swift build -c release --package-path "$ROOT_DIR"
BIN_DIR="$(swift build -c release --show-bin-path --package-path "$ROOT_DIR")"
BIN_PATH="${BIN_DIR}/${APP_NAME}"

if [[ -f "$ICON_SCRIPT" && ( ! -f "$ICON_SOURCE" || "$ICON_SCRIPT" -nt "$ICON_SOURCE" ) ]]; then
  print "==> Generating app icon"
  swift "$ICON_SCRIPT" "$ICON_SOURCE"
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$APP_BUNDLE/Contents/Helpers"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"
chmod +x "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"
cp "$ROOT_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "$APP_BUNDLE/Contents/Info.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "$APP_BUNDLE/Contents/Info.plist" >/dev/null

if [[ -d "$ROOT_DIR/Resources" ]]; then
  ditto "$ROOT_DIR/Resources" "$APP_BUNDLE/Contents/Resources"
fi

if HELPER_PATH="$(resolve_helper 2>/dev/null)"; then
  print "==> Embedding apfel helper from ${HELPER_PATH}"
  cp "$HELPER_PATH" "$APP_BUNDLE/Contents/Helpers/apfel"
  chmod +x "$APP_BUNDLE/Contents/Helpers/apfel"
else
  print "==> Warning: no apfel helper was found; packaged app will require apfel on PATH"
  rmdir "$APP_BUNDLE/Contents/Helpers" 2>/dev/null || true
fi

print "==> Built ${APP_BUNDLE}"
