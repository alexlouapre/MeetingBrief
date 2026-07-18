#!/bin/bash
set -euo pipefail

APP_NAME="MeetingBrief"
BUNDLE_ID="io.poppins.meetingbrief"
VERSION="0.1.0"

cd "$(dirname "$0")/.."

echo "→ Building release binary…"
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
BIN="$BIN_DIR/$APP_NAME"
if [ ! -f "$BIN" ]; then
    echo "Error: binary not found at $BIN"
    exit 1
fi

APP_DIR=".build/$APP_NAME.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

# Generate and embed app icon
if [ -f "assets/icon-source.png" ]; then
    ./scripts/make-icon.sh > /dev/null
    cp assets/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
    HAS_ICON=1
else
    HAS_ICON=0
fi

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>$([ "$HAS_ICON" = "1" ] && echo "
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>" || true)
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Ad-hoc sign so macOS can track the binary identity across launches
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true

echo "✓ App bundle created: $APP_DIR"
echo ""
echo "Next: run ./scripts/install.sh to install to /Applications + enable auto-launch"
