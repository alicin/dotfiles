#!/usr/bin/bash
# Area screenshot, macOS Cmd+Shift+4 style: drag-select a region, save it to
# ~/Pictures/Screenshots, and copy it to the clipboard. Cancelling the selection
# (Esc / right-click) exits cleanly without an error.

dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$dir"
file="$dir/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"

# slurp exits non-zero when the selection is cancelled — bail out quietly.
geometry="$(slurp)" || exit 0
[ -z "$geometry" ] && exit 0

grim -g "$geometry" "$file"
wl-copy < "$file"

notify-send "Screenshot saved" "$file" \
    -i "$file" \
    -a "Screenshot" \
    -t 10000 \
    --action="scriptAction:-xdg-open $(dirname "$file")=Open Directory" \
    --action="scriptAction:-xdg-open $file=Open"
