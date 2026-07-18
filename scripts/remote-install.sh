#!/bin/bash
# MeetingBrief remote installer — meant to be piped from curl:
#   curl -fsSL https://raw.githubusercontent.com/alexlouapre/MeetingBrief/main/scripts/remote-install.sh | bash
set -euo pipefail

REPO="${MEETINGBRIEF_REPO:-https://github.com/alexlouapre/MeetingBrief.git}"

# 1. macOS 26+ required (Liquid Glass APIs)
MACOS_MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
if [ "$MACOS_MAJOR" -lt 26 ]; then
    echo "Error: MeetingBrief requires macOS 26 (Tahoe) or later — you are on $(sw_vers -productVersion)."
    exit 1
fi

# 2. Xcode command-line tools
if ! xcode-select -p >/dev/null 2>&1; then
    echo "Error: Xcode command-line tools are not installed."
    echo "Run:  xcode-select --install"
    echo "…then re-run this installer."
    exit 1
fi

# 3. Swift 6.2+
SWIFT_VERSION="$(swift --version 2>/dev/null | grep -oE 'Swift version [0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+' | head -1)"
if [ -z "$SWIFT_VERSION" ]; then
    echo "Error: swift not found. Install the Xcode command-line tools first."
    exit 1
fi
SWIFT_MAJOR="${SWIFT_VERSION%%.*}"
SWIFT_MINOR="${SWIFT_VERSION#*.}"
if [ "$SWIFT_MAJOR" -lt 6 ] || { [ "$SWIFT_MAJOR" -eq 6 ] && [ "$SWIFT_MINOR" -lt 2 ]; }; then
    echo "Error: Swift 6.2+ required (found $SWIFT_VERSION). Update your command-line tools:"
    echo "  softwareupdate --install --all"
    exit 1
fi

# 4. Clone into a temp dir and install
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "→ Cloning ${REPO}..."
git clone --depth 1 "$REPO" "$TMP/MeetingBrief"

bash "$TMP/MeetingBrief/scripts/install.sh"
