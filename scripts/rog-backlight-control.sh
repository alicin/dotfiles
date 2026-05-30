#!/usr/bin/env bash
set -euo pipefail

STEP=10

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

# Read current brightness % from the first available device
PRIMARY="${DEVICES[0]}"
cur_pct="$(brightnessctl -d "$PRIMARY" -m | awk -F, '{gsub(/%/,"",$4); print $4}')"

# Compute next % with clamping
next_pct=$(( cur_pct + (DIR * STEP) ))
if (( next_pct < 1 )); then next_pct=1; fi
if (( next_pct > 100 )); then next_pct=100; fi

# Apply to all detected backlights
for d in "${DEVICES[@]}"; do
  brightnessctl -d "$d" set "${next_pct}%" >/dev/null 2>&1
done

echo "Set brightness to ${next_pct}% on: ${DEVICES[*]}"
