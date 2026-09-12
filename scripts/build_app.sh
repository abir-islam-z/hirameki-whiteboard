#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

if [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk" ]; then
    export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
elif [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk" ]; then
    export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk"
fi

echo "==> Building Hirameki Whiteboard (Release) with SDKROOT=${SDKROOT:-default}..."
swift build -c release

RELEASE_BIN="$DIR/.build/release/HiramekiWhiteboard"
BUILD_DIR="$DIR/build"
DIST_DIR="$BUILD_DIR/dist"
APP_NAME="Hirameki Whiteboard.app"
APP_BUNDLE="$DIST_DIR/$APP_NAME"

echo "==> Cleaning previous distribution artifacts..."
rm -rf "$BUILD_DIR"

mkdir -p "$DIST_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "==> Copying executable..."
cp "$RELEASE_BIN" "$APP_BUNDLE/Contents/MacOS/HiramekiWhiteboard"
chmod +x "$APP_BUNDLE/Contents/MacOS/HiramekiWhiteboard"

echo "==> Setting up AppIcon..."
if [ -f "$DIR/Resources/AppIcon.icns" ]; then
    cp "$DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

echo "==> Generating Info.plist..."
cat << 'EOF' > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>HiramekiWhiteboard</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>dev.hirameki.Whiteboard</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Hirameki Whiteboard</string>
    <key>CFBundleDisplayName</key>
    <string>Hirameki Whiteboard</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Hirameki Whiteboard Document</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>LSHandlerRank</key>
            <string>Owner</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>dev.hirameki.whiteboard</string>
            </array>
        </dict>
        <dict>
            <key>CFBundleTypeName</key>
            <string>PDF Document</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>com.adobe.pdf</string>
            </array>
        </dict>
    </array>
    <key>UTExportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>dev.hirameki.whiteboard</string>
            <key>UTTypeDescription</key>
            <string>Hirameki Whiteboard Document</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.data</string>
                <string>public.content</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>hiramekiboard</string>
                </array>
            </dict>
        </dict>
    </array>
</dict>
</plist>
EOF

echo "==> Ad-hoc code signing application bundle..."
codesign --force --deep --sign - --requirements '=designated => identifier "dev.hirameki.Whiteboard"' "$APP_BUNDLE"

echo "==> Hirameki Whiteboard.app created successfully at: $APP_BUNDLE"
