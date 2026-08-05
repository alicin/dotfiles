#!/usr/bin/bash
# Screenshots, macOS style: drag-select a region (Cmd+Shift+4), pick a window,
# or grab the whole screen. Saves to ~/Pictures/Screenshots and copies to the
# clipboard. Cancelling the selection (Esc / right-click) exits cleanly.
#
#   usage: screenshot.sh [area|window|full]
#
# This is the only screenshot implementation: qshell's Control Center runs it
# (services/Capture.qml) and so does the Ctrl+Shift+4 bind, which prefers the
# shell's IPC so the bar and toasts get out of the picture first, and falls back
# to running this directly when the shell isn't up (see hypr's apps.lua).

mode="${1:-area}"

# shellcheck source=lib/capture.sh
. "$(dirname "$(readlink -f "$0")")/lib/capture.sh"

# Tell the shell the capture is over on *every* path out — success, a cancelled
# selection, a failure mid-script — so it stops hiding its own UI.
trap capture_done EXIT

dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$dir"
file="$dir/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"

case "$mode" in
area)
    # slurp exits non-zero when the selection is cancelled — bail out quietly.
    geometry="$(slurp)" || exit 0
    [ -n "$geometry" ] || exit 0
    set -- -g "$geometry"
    ;;
window)
    # Boxes for mapped, non-hidden windows on whichever workspaces are visible
    # — one per monitor, so this stays right with more than one screen. Feeding
    # them to `slurp -r` means hovering highlights a whole window and clicking
    # takes exactly it, which beats grabbing `activewindow` (that's whatever had
    # focus before the Control Center opened).
    ws=$(hyprctl -j monitors | jq -c '[.[].activeWorkspace.id]')
    geometry="$(hyprctl -j clients | jq -r --argjson ws "$ws" '
        .[] | select(.mapped and (.hidden | not)
                     and (.workspace.id as $i | $ws | index($i)))
        | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' \
        | slurp -r -f '%x,%y %wx%h')" || exit 0
    [ -n "$geometry" ] || exit 0
    set -- -g "$geometry"
    ;;
full)
    set --
    ;;
*)
    echo "usage: $0 [area|window|full]" >&2
    exit 1
    ;;
esac

# Bail rather than announce a screenshot that isn't there: the notification's
# buttons act on this path, and a card whose Open does nothing is
# indistinguishable from a broken shell.
grim "$@" "$file" || exit 1

# wl-copy daemonises to serve the clipboard until something else claims it, and
# it inherits our stdout — so anything capturing this script's output would wait
# on a process that intends to outlive it. Hand it clean fds.
wl-copy <"$file" >/dev/null 2>&1

capture_saved "$file"
notify_capture "Screenshot saved" "$file" 8000 edit
