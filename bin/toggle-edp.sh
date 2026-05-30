#!/usr/bin/env bash
# Toggle eDP-1 monitor on/off

MONITOR="eDP-1"
MONITOR_CONFIG="2560x1600@240,0x0,1.33"

# Check if monitor is currently enabled
if hyprctl monitors | grep -q "^Monitor $MONITOR"; then
    # Monitor is on, disable it
    hyprctl keyword monitor "$MONITOR,disable"
else
    # Monitor is off, enable it
    hyprctl keyword monitor "$MONITOR,$MONITOR_CONFIG"
fi
