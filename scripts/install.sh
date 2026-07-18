#!/bin/bash
set -euo pipefail

APP_NAME="MeetingBrief"
BUNDLE_ID="io.poppins.meetingbrief"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

cd "$REPO_DIR"

# Build bundle first
"$SCRIPT_DIR/bundle.sh"

APP_SRC="$REPO_DIR/.build/$APP_NAME.app"
APP_DST="/Applications/$APP_NAME.app"

echo "→ Installing to /Applications…"
# Stop running instance if any
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 1

if [ -d "$APP_DST" ]; then
    rm -rf "$APP_DST"
fi
cp -R "$APP_SRC" "$APP_DST"

echo "→ Configuring auto-launch at login…"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
LAUNCH_AGENT="$LAUNCH_AGENT_DIR/${BUNDLE_ID}.plist"
mkdir -p "$LAUNCH_AGENT_DIR"

# Unload existing agent if present
launchctl unload "$LAUNCH_AGENT" 2>/dev/null || true

cat > "$LAUNCH_AGENT" <<AGENT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${BUNDLE_ID}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${APP_DST}/Contents/MacOS/${APP_NAME}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
AGENT

launchctl load "$LAUNCH_AGENT"
# LaunchAgent with RunAtLoad=true starts the app automatically — no need to also call `open`

echo ""
echo "✓ ${APP_NAME} installed at ${APP_DST}"
echo "✓ Auto-launch enabled (at next login)"
echo "✓ App started — icon should now be in your menu bar"
echo ""
echo "To uninstall:"
echo "  launchctl unload ${LAUNCH_AGENT}"
echo "  rm -rf ${APP_DST} ${LAUNCH_AGENT}"
