#!/bin/bash
set -euo pipefail

# Generates assets/AppIcon.icns from assets/icon-source.png

cd "$(dirname "$0")/.."

SRC="assets/icon-source.png"
OUT="assets/AppIcon.icns"
ICONSET="assets/AppIcon.iconset"

if [ ! -f "$SRC" ]; then
    echo "Error: source icon not found at $SRC"
    exit 1
fi

rm -rf "$ICONSET"
mkdir -p "$ICONSET"

# Required sizes for macOS icns: 16, 32, 128, 256, 512 @1x and @2x
sips -z 16   16   "$SRC" --out "$ICONSET/icon_16x16.png"      > /dev/null
sips -z 32   32   "$SRC" --out "$ICONSET/icon_16x16@2x.png"   > /dev/null
sips -z 32   32   "$SRC" --out "$ICONSET/icon_32x32.png"      > /dev/null
sips -z 64   64   "$SRC" --out "$ICONSET/icon_32x32@2x.png"   > /dev/null
sips -z 128  128  "$SRC" --out "$ICONSET/icon_128x128.png"    > /dev/null
sips -z 256  256  "$SRC" --out "$ICONSET/icon_128x128@2x.png" > /dev/null
sips -z 256  256  "$SRC" --out "$ICONSET/icon_256x256.png"    > /dev/null
sips -z 512  512  "$SRC" --out "$ICONSET/icon_256x256@2x.png" > /dev/null
sips -z 512  512  "$SRC" --out "$ICONSET/icon_512x512.png"    > /dev/null
sips -z 1024 1024 "$SRC" --out "$ICONSET/icon_512x512@2x.png" > /dev/null

iconutil -c icns "$ICONSET" -o "$OUT"
rm -rf "$ICONSET"

echo "✓ Icon generated: $OUT"
