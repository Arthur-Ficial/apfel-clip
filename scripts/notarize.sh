#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$ROOT_DIR/build/apfel-clip.app"
ZIP_PATH="$ROOT_DIR/dist/apfel-clip-notarize.zip"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:?set KEYCHAIN_PROFILE for xcrun notarytool}"

"$ROOT_DIR/scripts/build-app.sh"
"$ROOT_DIR/scripts/sign-app.sh" "$APP_PATH"

mkdir -p "$ROOT_DIR/dist"
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$KEYCHAIN_PROFILE" --wait
xcrun stapler staple "$APP_PATH"

print "==> Notarized and stapled ${APP_PATH}"
