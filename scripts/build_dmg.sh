#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

"$DIR/scripts/build_app.sh"

BUILD_DIR="$DIR/build"
STAGING_DIR="$BUILD_DIR/dmg_staging"
DMG_OUTPUT="$DIR/HiramekiWhiteboard.dmg"
APP_BUNDLE="$BUILD_DIR/dist/Hirameki Whiteboard.app"

echo "==> Preparing Whiteboard DMG staging..."
rm -rf "$STAGING_DIR"
rm -f "$DMG_OUTPUT"
mkdir -p "$STAGING_DIR"

cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

echo "==> Packaging HiramekiWhiteboard.dmg..."
hdiutil create \
    -volname "Hirameki Whiteboard" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_OUTPUT"

rm -rf "$STAGING_DIR"
echo "==> HiramekiWhiteboard.dmg successfully created at: $DMG_OUTPUT"
ls -lh "$DMG_OUTPUT"
