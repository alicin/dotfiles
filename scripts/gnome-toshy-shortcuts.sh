#!/bin/bash

# GNOME shortcuts tuned for Toshy + Hyprland-style muscle memory.
# Idempotent and safe to run on every Linux host: skips when GNOME gsettings
# schemas are unavailable. With Toshy active/present, physical Super is seen by
# GNOME as Alt when held, so GNOME must bind <Alt>number and <Alt>-drag.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/os-detection.sh"

if ! is_linux; then
    exit 0
fi

if ! command -v gsettings >/dev/null 2>&1; then
    echo "Skipping GNOME/Toshy shortcuts: gsettings not installed"
    exit 0
fi

has_schema() {
    local schema="$1"
    gsettings list-schemas | grep -qx "$schema"
}

if ! has_schema org.gnome.desktop.wm.keybindings; then
    echo "Skipping GNOME/Toshy shortcuts: GNOME WM keybinding schema unavailable"
    exit 0
fi

if ! has_schema org.gnome.desktop.wm.preferences; then
    echo "Skipping GNOME/Toshy shortcuts: GNOME WM preferences schema unavailable"
    exit 0
fi

# Toshy's default Windows-keyboard GUI mapping turns physical Super/Win into
# logical Alt when held. Prefer the Toshy-aware binding whenever Toshy config or
# services are present, even if services are not currently running during install.
uses_toshy=false
if [[ -d "${HOME}/.config/toshy" ]] || [[ -f "${HOME}/.config/systemd/user/toshy-config.service" ]]; then
    uses_toshy=true
elif systemctl --user list-unit-files 'toshy-*.service' >/dev/null 2>&1; then
    if systemctl --user list-unit-files 'toshy-*.service' 2>/dev/null | grep -q '^toshy-'; then
        uses_toshy=true
    fi
fi

if [[ "$uses_toshy" == "true" ]]; then
    shortcut_modifier="Alt"
else
    shortcut_modifier="Super"
fi

echo "Setting GNOME workspace shortcuts for physical Super (${shortcut_modifier} after Toshy mapping)"

# Hyprland-like fixed numeric workspaces when Mutter is present.
if has_schema org.gnome.mutter; then
    gsettings set org.gnome.mutter dynamic-workspaces false || true
fi
gsettings set org.gnome.desktop.wm.preferences num-workspaces 10 || true

for n in 1 2 3 4 5 6 7 8 9; do
    gsettings set org.gnome.desktop.wm.keybindings "switch-to-workspace-${n}" "['<${shortcut_modifier}>${n}']"
done
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-10 "['<${shortcut_modifier}>0']"

# GNOME Shell defaults Super+number to app favorites. Keep it out of the way for
# workspace switching and future Toshy changes.
if has_schema org.gnome.shell.keybindings; then
    for n in 1 2 3 4 5 6 7 8 9; do
        gsettings set org.gnome.shell.keybindings "switch-to-application-${n}" "[]"
    done
fi

# Hyprland muscle memory: physical Super + left/right drag to move/resize.
gsettings set org.gnome.desktop.wm.preferences mouse-button-modifier "'<${shortcut_modifier}>'"
gsettings set org.gnome.desktop.wm.preferences resize-with-right-button true

echo "GNOME workspace/mouse shortcuts configured"
