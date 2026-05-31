#!/usr/bin/env bash
# Toggle eDP-1 monitor on/off

MONITOR="eDP-1"
MONITOR_MODE="2560x1600@240"
MONITOR_POSITION="187x1296"
MONITOR_SCALE="1.33"
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

load_monitor_state() {
    if [[ -r "$STATE_FILE" ]]; then
        MONITOR_MODE=$(jq -r '.mode // empty' "$STATE_FILE")
        MONITOR_POSITION=$(jq -r '.position // empty' "$STATE_FILE")
        MONITOR_SCALE=$(jq -r '.scale // empty' "$STATE_FILE")
    fi

    MONITOR_MODE=${MONITOR_MODE:-2560x1600@240}
    MONITOR_POSITION=${MONITOR_POSITION:-187x1296}
    MONITOR_SCALE=${MONITOR_SCALE:-1.33}
}

# Check if monitor is currently enabled
if hyprctl monitors | grep -q "^Monitor $MONITOR"; then
    # Monitor is on, disable it
    save_monitor_state
    hyprctl -r eval "hl.monitor({ output = \"$MONITOR\", disabled = true })"
else
    # Monitor is off, enable it
    load_monitor_state
    hyprctl -r eval "hl.monitor({ output = \"$MONITOR\", disabled = false, mode = \"$MONITOR_MODE\", position = \"$MONITOR_POSITION\", scale = $MONITOR_SCALE })"
fi
