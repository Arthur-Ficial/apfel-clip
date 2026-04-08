#!/bin/zsh
set -euo pipefail

REPO="${REPO:-Arthur-Ficial/apfel-clip}"
APP_NAME="apfel-clip.app"
APP_DIR="${APP_DIR:-/Applications}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
TMP_DIR="$(mktemp -d)"
VERSION_ARG="${1:-latest}"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [[ "$VERSION_ARG" == "latest" ]]; then
  ASSET_URL="https://github.com/${REPO}/releases/latest/download/apfel-clip-macos-arm64.zip"
else
  TAG="$VERSION_ARG"
  [[ "$TAG" == v* ]] || TAG="v${TAG}"
  ASSET_URL="https://github.com/${REPO}/releases/download/${TAG}/apfel-clip-macos-arm64.zip"
fi

print "==> Downloading ${ASSET_URL}"
curl -fsSL "$ASSET_URL" -o "$TMP_DIR/apfel-clip.zip"
ditto -x -k "$TMP_DIR/apfel-clip.zip" "$TMP_DIR/unpacked"

mkdir -p "$BIN_DIR"

if [[ -w "$APP_DIR" ]]; then
  rm -rf "$APP_DIR/$APP_NAME"
  ditto "$TMP_DIR/unpacked/$APP_NAME" "$APP_DIR/$APP_NAME"
else
  sudo rm -rf "$APP_DIR/$APP_NAME"
  sudo ditto "$TMP_DIR/unpacked/$APP_NAME" "$APP_DIR/$APP_NAME"
fi

ln -sf "$APP_DIR/$APP_NAME/Contents/MacOS/apfel-clip" "$BIN_DIR/apfel-clip"

print "==> Installed ${APP_DIR}/${APP_NAME}"
print "==> Linked ${BIN_DIR}/apfel-clip"
print "==> Launch with: open -a ${APP_DIR}/${APP_NAME}"
