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

# 2. Xcode command-line tools — required to compile from source.
if ! xcode-select -p >/dev/null 2>&1; then
    echo "→ Xcode command-line tools not found — installing (this can take a few minutes)…"

    # Headless install via softwareupdate (no GUI click; prompts for the admin
    # password once). The trigger file makes softwareupdate list the CLT package.
    CLT_TRIGGER="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
    touch "$CLT_TRIGGER"
    CLT_LABEL="$(softwareupdate -l 2>/dev/null \
        | grep -E '^\s*\* Label:.*Command Line Tools' \
        | sed -E 's/^[[:space:]]*\* Label:[[:space:]]*//' \
        | tail -1)"

    CLT_OK=0
    if [ -n "$CLT_LABEL" ]; then
        echo "→ Installing \"$CLT_LABEL\" (may prompt for your admin password)…"
        if sudo softwareupdate -i "$CLT_LABEL" --verbose; then
            CLT_OK=1
        fi
    fi
    rm -f "$CLT_TRIGGER"

    if [ "$CLT_OK" -ne 1 ] || ! xcode-select -p >/dev/null 2>&1; then
        # Fallback: the graphical installer (no password, but needs a manual click).
        echo "→ Headless install unavailable — opening the graphical installer instead."
        xcode-select --install 2>/dev/null || true
        echo ""
        echo "A macOS dialog should have opened. Click \"Install\", accept the licence,"
        echo "and wait for it to finish. Then re-run this installer."
        exit 1
    fi
    echo "✓ Command-line tools installed."
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
