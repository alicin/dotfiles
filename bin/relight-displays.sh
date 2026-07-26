#!/usr/bin/env bash
# Panic recovery for a stuck / blank display (esp. the eDP laptop panel).
#
# Forces Hyprland to re-apply its monitor config, which does a full modeset and
# relights a panel that got stuck off — e.g. after an s2idle lid-resume that
# left the panel dark, or a one-way `toggle-edp.sh` disable that couldn't
# re-enable (in this Hyprland/aquamarine version `hl.monitor({disabled=false})`
# returns "ok" but never re-adds a disabled connector; `hyprctl reload` does).
#
# Safe to run anytime: `hyprctl reload` re-applies monitors/binds/rules but does
# NOT re-run startup apps — those fire on hyprland.start (see lua/startup.lua).
set -uo pipefail

# Reach the running compositor even if launched without its env (e.g. over SSH).
if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    export HYPRLAND_INSTANCE_SIGNATURE="$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr" 2>/dev/null | head -1)"
fi

# 1. Re-apply monitor config -> full modeset -> relights stuck panels.
hyprctl reload >/dev/null 2>&1

# 2. Make sure DPMS is on.
hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })' >/dev/null 2>&1

# 3. If the backlight got driven near zero (e.g. hypridle dimming), bring it back.
if cur=$(brightnessctl -c backlight g 2>/dev/null) && max=$(brightnessctl -c backlight m 2>/dev/null); then
    if [[ -n "$cur" && -n "$max" && "$cur" -lt $((max / 20)) ]]; then
        brightnessctl -c backlight set 40% >/dev/null 2>&1
    fi
fi
