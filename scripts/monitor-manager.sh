#!/usr/bin/env bash
set -euo pipefail

# Hyprland Monitor Manager - udev rule installer
# This script installs udev rules to automatically manage workspaces when monitors are connected/disconnected

# Target user
TARGET_USER="ali"
TARGET_UID="$(id -u "$TARGET_USER")"
RUNTIME_DIR="/run/user/${TARGET_UID}"

HELPER="/home/ali/labs/dotfiles/bin/hypr-monitor-manager.sh"
RULE="/etc/udev/rules.d/99-hyprland-monitor-hotplug.rules"

echo "Installing Hyprland monitor management udev rules..."

# Create the udev rule for monitor hotplug detection
cat <<EOF >"$RULE"
# Hyprland Monitor Hotplug Management
# Automatically manage workspaces when external monitors are connected/disconnected

# Monitor connection events
ACTION=="change", KERNEL=="card[0-9]*", SUBSYSTEM=="drm", ENV{HOTPLUG}=="1", RUN+="$HELPER add"

# Alternative rules for different systems - monitor connection via DisplayPort/HDMI
ACTION=="change", SUBSYSTEM=="drm", ENV{HOTPLUG}=="1", RUN+="$HELPER auto"

# USB-C/Thunderbolt monitor detection
ACTION=="add", SUBSYSTEM=="usb", ENV{ID_USB_INTERFACES}=="*:ff4240:*", RUN+="$HELPER add"
ACTION=="remove", SUBSYSTEM=="usb", ENV{ID_USB_INTERFACES}=="*:ff4240:*", RUN+="$HELPER remove"

# General display connector change detection
SUBSYSTEM=="drm", ACTION=="change", RUN+="$HELPER auto"
EOF

chmod 0644 "$RULE"
echo "Rule installed: $RULE"

# Make the helper script executable
chmod +x "$HELPER"
echo "Made helper script executable: $HELPER"

# Reload & apply udev rules
udevadm control --reload-rules
udevadm trigger --subsystem-match=drm
echo "Reloaded udev rules and triggered drm subsystem events"

echo
echo "Monitor management is now active!"
echo
echo "Manual testing commands:"
echo "  sudo $HELPER add           # Simulate monitor connect"
echo "  sudo $HELPER remove        # Simulate monitor disconnect"
echo "  sudo $HELPER auto          # Auto-detect current setup"
echo "  sudo $HELPER setup-external # Force external layout"
echo "  sudo $HELPER setup-laptop  # Force laptop-only layout"
echo "  sudo $HELPER status        # Show monitor status"
echo
echo "Check logs:"
echo "  journalctl -t hypr-monitor-manager -f"
echo
echo "To uninstall:"
echo "  sudo rm $RULE"
echo "  sudo udevadm control --reload-rules"