#!/usr/bin/env bash
# Toggle eDP-1 refresh rate between 60Hz and the panel's fastest mode.
#
# The high rate is read from availableModes, not hardcoded: a fixed 240 was
# h4l9000's panel, and on k3v1n (120Hz) the toggle asked for a mode that
# doesn't exist. This script is shared bin/ — it must know only what the
# machine it runs on reports.

MONITOR="eDP-1"
LOW_REFRESH="60"

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
        .scale,
        ((.availableModes // []) | join(" "))
    ]
    | @tsv
')

if [[ -z "$monitor_state" ]]; then
    hyprctl notify 3 4000 "rgb(ff5f5f)" "Monitor $MONITOR not found"
    exit 1
fi

IFS=$'\t' read -r disabled width height refresh_rate x y scale modes <<< "$monitor_state"

if [[ "$disabled" == "true" ]]; then
    hyprctl notify 2 4000 "rgb(ffc857)" "Monitor $MONITOR is disabled"
    exit 1
fi

# Fastest refresh offered at the CURRENT resolution ("2560x1600@120.00Hz" ...).
high_refresh=$(tr ' ' '\n' <<< "$modes" | grep -F "${width}x${height}@" \
    | sed -E 's/.*@([0-9]+).*/\1/' | sort -n | tail -1)
if [[ -z "$high_refresh" || "$high_refresh" -le "$LOW_REFRESH" ]]; then
    hyprctl notify 2 4000 "rgb(ffc857)" "$MONITOR has no mode above ${LOW_REFRESH}Hz"
    exit 1
fi

if (( ${refresh_rate%.*} > LOW_REFRESH )); then
    target_refresh="$LOW_REFRESH"
else
    target_refresh="$high_refresh"
fi

mode="${width}x${height}@${target_refresh}"
position="${x}x${y}"

hyprctl -r eval "hl.monitor({ output = \"$MONITOR\", mode = \"$mode\", position = \"$position\", scale = $scale })"
hyprctl notify 1 2500 "rgb(8aadf4)" "$MONITOR refresh: ${target_refresh}Hz"