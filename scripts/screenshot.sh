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

# Bail rather than announce a screenshot that isn't there: the notification's
# buttons act on this path, and a card whose Open does nothing is
# indistinguishable from a broken shell.
grim -g "$geometry" "$file" || exit 1
wl-copy < "$file"

# Posted the way qshell's own capture module does it, because the actions are
# carried out by the shell (Notifs.runAction), not by whoever posted the card.
#
# This used to be `notify-send --action="scriptAction:-xdg-open $file=Open"`,
# a HyprPanel convention: its notification widget parsed the `scriptAction:-`
# prefix and ran the rest as a command. qshell replaced HyprPanel and has no
# such handler, so those buttons silently did nothing. Worse, notify-send
# --action blocks until the notification is dismissed or times out, so the
# process lingered for 10s and the buttons died with it.
#
# The identifiers are bare verbs and the path is the body: the shell operates
# on the path the card is showing, so a button can't do anything other than
# what it says. gdbus returns immediately and leaves the actions to the shell,
# where they keep working for as long as the notification exists.
gdbus call --session --dest org.freedesktop.Notifications \
    --object-path /org/freedesktop/Notifications \
    --method org.freedesktop.Notifications.Notify \
    qshell 0 "$file" "Screenshot saved" "$file" \
    "['qshell-open','Open','qshell-reveal','Show in folder']" \
    "{}" 10000 >/dev/null
