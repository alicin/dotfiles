#!/usr/bin/env bash
# Toggle eDP-1 refresh rate between 60Hz and 240Hz.

MONITOR="eDP-1"
LOW_REFRESH="60"
HIGH_REFRESH="240"

monitor_state=$(hyprctl -j monitors all | jq --arg monitor "$MONITOR" -r '
    .[]
    | select(.name == $monitor)
    | [
        .disabled,
        .width,
        .height,
        .refreshRate,
        .x,
        .y,
        .scale
    ]
    | @tsv
')

if [[ -z "$monitor_state" ]]; then
    hyprctl notify 3 4000 "rgb(ff5f5f)" "Monitor $MONITOR not found"
    exit 1
fi

IFS=$'\t' read -r disabled width height refresh_rate x y scale <<< "$monitor_state"

if [[ "$disabled" == "true" ]]; then
    hyprctl notify 2 4000 "rgb(ffc857)" "Monitor $MONITOR is disabled"
    exit 1
fi

if (( ${refresh_rate%.*} >= 120 )); then
    target_refresh="$LOW_REFRESH"
else
    target_refresh="$HIGH_REFRESH"
fi

mode="${width}x${height}@${target_refresh}"
position="${x}x${y}"

hyprctl -r eval "hl.monitor({ output = \"$MONITOR\", mode = \"$mode\", position = \"$position\", scale = $scale })"
hyprctl notify 1 2500 "rgb(8aadf4)" "$MONITOR refresh: ${target_refresh}Hz"