#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
ZIP_PATH="$DIST_DIR/apfel-clip-macos-$(uname -m).zip"
VERSION="$(tr -d '\n' < "$ROOT_DIR/.version")"
SHA="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
TAP_NAME="local/apfel-clip-install-test"
TMP_ROOT="$(mktemp -d)"
SERVER_PID=""

export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ENV_HINTS=1

pick_port() {
  python3 - <<'PY'
import socket
sock = socket.socket()
sock.bind(("127.0.0.1", 0))
print(sock.getsockname()[1])
sock.close()
PY
}

cleanup() {
  if brew list --cask "$TAP_NAME/apfel-clip" >/dev/null 2>&1; then
    brew uninstall --cask "$TAP_NAME/apfel-clip" >/dev/null 2>&1 || true
  fi

  if brew tap | rg -qx "$TAP_NAME"; then
    brew untap "$TAP_NAME" >/dev/null 2>&1 || true
  fi

  if [[ -n "$SERVER_PID" ]]; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
  fi

  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

if [[ ! -f "$ZIP_PATH" ]]; then
  print "==> dist zip missing; building release artifacts first"
  "$ROOT_DIR/scripts/build-dist.sh"
  SHA="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
fi

PORT="$(pick_port)"
ASSET_URL="http://127.0.0.1:${PORT}/$(basename "$ZIP_PATH")"

python3 -m http.server "$PORT" --directory "$DIST_DIR" >/tmp/apfel-clip-install-methods.log 2>&1 &
SERVER_PID=$!
sleep 1

assert_signed_and_notarized() {
  local app="$1"
  local label="$2"
  codesign --verify --deep --strict "$app" \
    || { print "FAIL [$label]: codesign invalid"; exit 1; }
  xcrun stapler validate "$app" >/dev/null 2>&1 \
    || { print "FAIL [$label]: notarization ticket missing (app will show 'damaged' when downloaded)"; exit 1; }
  spctl --assess --type exec "$app" >/dev/null 2>&1 \
    || { print "FAIL [$label]: Gatekeeper rejected (source not Notarized Developer ID)"; exit 1; }
  print "  OK: signed + notarized + Gatekeeper accepted [$label]"
}

print "==> 0/4 Verify dist zip contains notarized app"
VERIFY_TMP="$(mktemp -d)"
ditto -x -k "$ZIP_PATH" "$VERIFY_TMP"
assert_signed_and_notarized "$VERIFY_TMP/apfel-clip.app" "zip contents"
rm -rf "$VERIFY_TMP"

print "==> 1/4 Homebrew tap install"
APP_URL_OVERRIDE="$ASSET_URL" "$ROOT_DIR/scripts/render-homebrew-cask.sh" "$VERSION" "$SHA" > "$TMP_ROOT/apfel-clip.rb"
if brew tap | rg -qx "$TAP_NAME"; then
  brew untap "$TAP_NAME" >/dev/null 2>&1 || true
fi
brew tap-new "$TAP_NAME" --no-git >/dev/null
TAP_DIR="$(brew --repository)/Library/Taps/local/homebrew-apfel-clip-install-test"
mkdir -p "$TAP_DIR/Casks"
cp "$TMP_ROOT/apfel-clip.rb" "$TAP_DIR/Casks/apfel-clip.rb"
HOMEBREW_APPDIR="$TMP_ROOT/homebrew/Applications"
brew install --cask "$TAP_NAME/apfel-clip" --appdir="$HOMEBREW_APPDIR" >/dev/null
[[ -d "$HOMEBREW_APPDIR/apfel-clip.app" ]]
assert_signed_and_notarized "$HOMEBREW_APPDIR/apfel-clip.app" "homebrew"
brew uninstall --cask "$TAP_NAME/apfel-clip" >/dev/null
brew untap "$TAP_NAME" >/dev/null

print "==> 2/4 Direct zip download"
cp "$ZIP_PATH" "$TMP_ROOT/"
(
  cd "$TMP_ROOT"
  unzip -q "$(basename "$ZIP_PATH")"
)
[[ -d "$TMP_ROOT/apfel-clip.app" ]]
assert_signed_and_notarized "$TMP_ROOT/apfel-clip.app" "zip-unzip"

print "==> 3/4 curl installer"
APP_DIR="$TMP_ROOT/curl/Applications" \
BIN_DIR="$TMP_ROOT/curl/bin" \
ASSET_URL_OVERRIDE="$ASSET_URL" \
  "$ROOT_DIR/scripts/install.sh" >/dev/null
[[ -d "$TMP_ROOT/curl/Applications/apfel-clip.app" ]]
[[ -L "$TMP_ROOT/curl/bin/apfel-clip" ]]
assert_signed_and_notarized "$TMP_ROOT/curl/Applications/apfel-clip.app" "curl-installer"

print "==> 4/4 Build from source"
make -C "$ROOT_DIR" install-cli APP_DIR="$TMP_ROOT/source/Applications" BIN_DIR="$TMP_ROOT/source/bin" >/dev/null
[[ -d "$TMP_ROOT/source/Applications/apfel-clip.app" ]]
[[ -L "$TMP_ROOT/source/bin/apfel-clip" ]]
codesign --verify --deep --strict "$TMP_ROOT/source/Applications/apfel-clip.app" \
  || { print "FAIL [source]: codesign invalid"; exit 1; }
print "  OK: codesign valid [source] (source builds are not notarized — expected)"

print "==> All install methods passed"
