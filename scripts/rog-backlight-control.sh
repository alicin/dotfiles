#!/usr/bin/env bash
set -euo pipefail

STEP=10
DEVICES=("intel_backlight" "nvidia_0")

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

# Read current brightness % from intel_backlight (stable + high resolution)
cur_pct="$(brightnessctl -d intel_backlight -m | awk -F, '{gsub(/%/,"",$4); print $4}')"

# Compute next % with clamping
next_pct=$(( cur_pct + (DIR * STEP) ))
if (( next_pct < 1 )); then next_pct=1; fi
if (( next_pct > 100 )); then next_pct=100; fi

# Apply to both backlights
for d in "${DEVICES[@]}"; do
  brightnessctl -d "$d" set "${next_pct}%"
done

echo "Set brightness to ${next_pct}% on: ${DEVICES[*]}"
