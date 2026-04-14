#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${APP_NAME:-z0d1ak}"
BUNDLE_ID="${BUNDLE_ID:-io.z0d1ak}"
MIN_SYSTEM_VERSION="${MIN_SYSTEM_VERSION:-26.0}"
APP_VERSION="${APP_VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
CONFIGURATION="${CONFIGURATION:-release}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$(swift build --configuration "$CONFIGURATION" --show-bin-path)"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist/release}"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ZIP_PATH="$DIST_DIR/$APP_NAME.zip"
APP_ICON_SOURCE="${APP_ICON_SOURCE:-$ROOT_DIR/Assets/AppIcon.icns}"

SIGN_APP="${SIGN_APP:-0}"
NOTARIZE_APP="${NOTARIZE_APP:-0}"

mkdir -p "$DIST_DIR"
rm -rf "$APP_BUNDLE" "$ZIP_PATH"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"

swift build --configuration "$CONFIGURATION"
cp "$BUILD_DIR/$APP_NAME" "$APP_BINARY"
chmod +x "$APP_BINARY"

if [[ -f "$APP_ICON_SOURCE" ]]; then
  cp "$APP_ICON_SOURCE" "$APP_RESOURCES/AppIcon.icns"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>z0d1ak</string>
  <key>CFBundleDisplayName</key>
  <string>z0d1ak</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

if [[ "$SIGN_APP" == "1" ]]; then
  : "${APPLE_SIGNING_IDENTITY:?APPLE_SIGNING_IDENTITY is required when SIGN_APP=1}"
  codesign \
    --force \
    --timestamp \
    --options runtime \
    --sign "$APPLE_SIGNING_IDENTITY" \
    "$APP_BUNDLE"

  codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
fi

/usr/bin/ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

if [[ "$NOTARIZE_APP" == "1" ]]; then
  : "${APPLE_NOTARY_KEY_PATH:?APPLE_NOTARY_KEY_PATH is required when NOTARIZE_APP=1}"
  : "${APPLE_NOTARY_KEY_ID:?APPLE_NOTARY_KEY_ID is required when NOTARIZE_APP=1}"
  : "${APPLE_NOTARY_ISSUER_ID:?APPLE_NOTARY_ISSUER_ID is required when NOTARIZE_APP=1}"

  xcrun notarytool submit "$ZIP_PATH" \
    --key "$APPLE_NOTARY_KEY_PATH" \
    --key-id "$APPLE_NOTARY_KEY_ID" \
    --issuer "$APPLE_NOTARY_ISSUER_ID" \
    --wait

  xcrun stapler staple "$APP_BUNDLE"
  rm -f "$ZIP_PATH"
  /usr/bin/ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"
  spctl -a -vv "$APP_BUNDLE"
fi

printf 'App bundle: %s\nZip archive: %s\n' "$APP_BUNDLE" "$ZIP_PATH"
