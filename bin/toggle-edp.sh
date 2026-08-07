#!/usr/bin/env bash
# Toggle eDP-1 monitor on/off

MONITOR="eDP-1"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
STATE_FILE="$STATE_DIR/toggle-edp.json"

save_monitor_state() {
    local state

    state=$(hyprctl -j monitors | jq --arg monitor "$MONITOR" '
        .[]
        | select(.name == $monitor)
        | {
            mode: "\(.width)x\(.height)@\(.refreshRate)",
            position: "\(.x)x\(.y)",
            scale: .scale
        }
    ')

    if [[ -n "$state" ]]; then
        mkdir -p "$STATE_DIR"
        printf '%s\n' "$state" > "$STATE_FILE"
    fi
}

# Check if monitor is currently enabled
if hyprctl monitors | grep -q "^Monitor $MONITOR"; then
    # Monitor is on, disable it.
    save_monitor_state
    hyprctl -r eval "hl.monitor({ output = \"$MONITOR\", disabled = true })"
else
    # Monitor is off, re-enable it.
    #
    # NOTE: `hl.monitor({ disabled = false, ... })` returns "ok" but does NOT
    # re-add a disabled connector in the current Hyprland/aquamarine — the panel
    # stays dark. So recover via `hyprctl reload`, which re-applies the host
    # monitor config (canonical mode/position/scale) and forces a real modeset.
    exec "$(dirname "$(readlink -f "$0")")/relight-displays.sh"
fi
