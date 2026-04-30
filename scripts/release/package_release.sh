#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MacMicWidget"
BUNDLE_ID="com.ilyabazhenov.mac-mic-widget"
VERSION="${1:-v0.1.0}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/release"
DIST_DIR="$ROOT_DIR/dist/$VERSION"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ZIP_PATH="$DIST_DIR/$APP_NAME-$VERSION-macos-arm64-unsigned.zip"
CHECKSUM_PATH="$DIST_DIR/SHA256SUMS.txt"

echo "==> Building release binary"
swift build -c release --package-path "$ROOT_DIR"

if [[ ! -x "$BUILD_DIR/$APP_NAME" ]]; then
  echo "ERROR: release executable not found at $BUILD_DIR/$APP_NAME"
  exit 1
fi

echo "==> Preparing app bundle"
rm -rf "$DIST_DIR"
mkdir -p "$MACOS_DIR"
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
mkdir -p "$RESOURCES_DIR"
if [[ -f "$ROOT_DIR/assets/AppIcon.icns" ]]; then
  cp "$ROOT_DIR/assets/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION#v}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION#v}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
EOF

echo "==> Creating distributable zip"
(
  cd "$DIST_DIR"
  ditto -c -k --sequesterRsrc --keepParent "$APP_NAME.app" "$(basename "$ZIP_PATH")"
)

echo "==> Calculating checksum"
(
  cd "$DIST_DIR"
  shasum -a 256 "$(basename "$ZIP_PATH")" > "$CHECKSUM_PATH"
)

echo
echo "Created:"
echo "  App bundle: $APP_DIR"
echo "  Zip:        $ZIP_PATH"
echo "  Checksum:   $CHECKSUM_PATH"
