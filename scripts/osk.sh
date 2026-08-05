#!/usr/bin/env bash
set -euo pipefail

# Installs the udev rule that toggles the GNOME on-screen keyboard when a
# physical keyboard is attached/detached -- the detachable-keyboard case on the
# k3v1n convertible.
#
# Needs root: it writes /etc/udev/rules.d and calls udevadm. profile-install.sh
# runs post_install scripts as the invoking user, and with `set -e` the very
# first redirect into /etc/udev/rules.d aborted the script, so this never
# actually got installed. Re-exec under sudo instead of failing.
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
        echo "Re-running with sudo..."
        exec sudo -- "$0" "$@"
    fi
    echo "Please run as root (e.g., sudo bash $0)" >&2
    exit 1
fi

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
