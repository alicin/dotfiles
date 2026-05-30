#!/usr/bin/env bash
# Called by udev: $1 = add|remove
set -euo pipefail

TARGET_USER="ali"
TARGET_UID="1000"
RUNTIME_DIR="/run/user/1000"
DBUS_ADDR="unix:path=/run/user/1000/bus"

ACTION="${1:-}"

# Make sure user session bus exists
if [[ ! -S "$RUNTIME_DIR/bus" ]]; then
  logger -t gnome-osk-toggle "User session bus not found at $RUNTIME_DIR/bus; skipping (action=$ACTION)."
  exit 0
fi

# Build env for Ali's session
export XDG_RUNTIME_DIR="$RUNTIME_DIR"
export DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR"

# Choose desired state based on action
if [[ "$ACTION" == "add" || "$ACTION" == "disable" ]]; then
  # Physical keyboard connected OR disable action -> disable on-screen keyboard
  DESIRED=false
elif [[ "$ACTION" == "remove" || "$ACTION" == "enable" ]]; then
  # Physical keyboard removed OR enable action -> enable on-screen keyboard
  DESIRED=true
else
  logger -t gnome-osk-toggle "Unknown action: $ACTION"
  exit 0
fi

# Run gsettings as Ali within his session
if command -v runuser >/dev/null 2>&1; then
  runuser -u "$TARGET_USER" -- env XDG_RUNTIME_DIR="$RUNTIME_DIR" DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR"     gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled "$DESIRED"     && logger -t gnome-osk-toggle "Set screen-keyboard-enabled=$DESIRED (action=$ACTION)"     || logger -t gnome-osk-toggle "FAILED to set screen-keyboard-enabled (action=$ACTION)"
else
  su - "$TARGET_USER" -c "XDG_RUNTIME_DIR='$RUNTIME_DIR' DBUS_SESSION_BUS_ADDRESS='$DBUS_ADDR' gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled '$DESIRED'"     && logger -t gnome-osk-toggle "Set screen-keyboard-enabled=$DESIRED (action=$ACTION)"     || logger -t gnome-osk-toggle "FAILED to set screen-keyboard-enabled (action=$ACTION)"
fi