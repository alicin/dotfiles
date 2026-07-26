#!/usr/bin/env bash
set -euo pipefail

STEP=10

# This panel is driven over the eDP HDR backlight interface (i915.enable_dpcd_backlight=3),
# whose raw register spans the full HDR luminance. In normal SDR desktop use the visible
# brightness maxes out around the top ~20% of that register (dead HDR headroom), and it
# never gets brighter past it. So map a logical 1-100% onto the panel's *useful* 1-MAX_PCT%,
# so 100% == the panel's real max brightness and the whole key travel does something.
# If the very top presses still don't get brighter, lower this (try 70). Keep it a multiple
# of 10 so the logical<->physical rounding stays stable.
MAX_PCT=80

usage() {
  echo "Usage: $(basename "$0") up|down"
  exit 1
}

[[ $# -eq 1 ]] || usage
case "$1" in
  up)   DIR=1 ;;
  down) DIR=-1 ;;
  *) usage ;;
esac

# Detect available backlight devices
DEVICES=()
for device in intel_backlight nvidia_0 amdgpu_bl0; do
  if [[ -d "/sys/class/backlight/$device" ]]; then
    DEVICES+=("$device")
  fi
done

if [[ ${#DEVICES[@]} -eq 0 ]]; then
  echo "Error: No backlight devices found" >&2
  exit 1
fi

# Read the device's current physical %, convert it onto our logical 0-100 scale
PRIMARY="${DEVICES[0]}"
cur_phys="$(brightnessctl -d "$PRIMARY" -m | awk -F, '{gsub(/%/,"",$4); print $4}')"
cur_pct=$(( (cur_phys * 100 + MAX_PCT / 2) / MAX_PCT ))   # physical% -> logical% (rounded)

# Step and clamp on the logical scale
next_pct=$(( cur_pct + (DIR * STEP) ))
if (( next_pct < 1 )); then next_pct=1; fi
if (( next_pct > 100 )); then next_pct=100; fi

# Convert the logical target back to the physical % we actually write
next_phys=$(( (next_pct * MAX_PCT + 50) / 100 ))         # logical% -> physical% (rounded)
if (( next_phys < 1 )); then next_phys=1; fi

# Apply to all detected backlights
for d in "${DEVICES[@]}"; do
  brightnessctl -d "$d" set "${next_phys}%" >/dev/null 2>&1
done

echo "Set brightness to ${next_pct}% (panel ${next_phys}%) on: ${DEVICES[*]}"
