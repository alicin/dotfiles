#!/usr/bin/env bash
set -euo pipefail

# Target user
TARGET_USER="ali"
TARGET_UID="$(id -u "$TARGET_USER")"
RUNTIME_DIR="/run/user/${TARGET_UID}"
DBUS_ADDR="unix:path=${RUNTIME_DIR}/bus"

HELPER="/home/ali/labs/dotfiles/bin/osk-toggle.sh"
RULE="/etc/udev/rules.d/90-any-keyboard-toggle.rules"

# Create a generic "any keyboard" udev rule
cat <<EOF >"$RULE"
# Toggle GNOME on-screen keyboard for ANY keyboard add/remove
ACTION=="add", SUBSYSTEM=="input", ENV{ID_INPUT_KEYBOARD}=="1", RUN+="$HELPER disable"
ACTION=="remove", SUBSYSTEM=="input", ENV{ID_INPUT_KEYBOARD}=="1", RUN+="$HELPER enable"
EOF
chmod 0644 "$RULE"
echo "Rule installed: $RULE"

# Reload & apply udev rules
udevadm control --reload-rules
udevadm trigger
echo "Reloaded udev. Done."

echo
echo "Test manually (no unplug needed):"
echo "  sudo $HELPER add    # simulates keyboard connect -> disables OSK"
echo "  sudo $HELPER remove # simulates keyboard disconnect -> enables OSK"
echo
echo "Check logs:"
echo "  journalctl -t gnome-osk-toggle -e"
