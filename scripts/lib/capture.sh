# Shared bits for the capture scripts (screenshot.sh, screen_record.sh).
# Sourced, not executed.

# Post a capture notification whose buttons actually work.
#
# The actions are carried out by qshell (services/Notifs.qml, runAction) rather
# than by whoever posted the card. That indirection is the whole point: a script
# that posts with `notify-send --action` has to sit in a glib loop waiting for
# the click and exits when the notification expires, so the buttons are dead a
# few seconds later when you find the card in the notification centre. gdbus
# returns immediately and leaves the verbs to the shell, where they keep working
# for as long as the notification exists.
#
# These used to be `--action="scriptAction:-xdg-open $path=Open"`, a HyprPanel
# convention: its notification widget stripped the `scriptAction:-` prefix and
# ran the rest as a command. qshell replaced HyprPanel and has no such handler,
# so every one of those buttons silently did nothing.
#
# The identifiers are bare verbs and the path travels as the body, so the shell
# acts on the path the card is already showing you — a button can't be talked
# into doing anything other than what it says.
notify_capture() {
    local summary="$1" path="$2" timeout="${3:-8000}"

    gdbus call --session --dest org.freedesktop.Notifications \
        --object-path /org/freedesktop/Notifications \
        --method org.freedesktop.Notifications.Notify \
        qshell 0 "$path" "$summary" "$path" \
        "['qshell-open','Open','qshell-reveal','Show in folder']" \
        "{}" "$timeout" >/dev/null
}

# A plain message with no file behind it — nothing to open, so no buttons.
notify_plain() {
    local summary="$1" body="$2" icon="${3:-video-x-generic}" timeout="${4:-4000}"

    gdbus call --session --dest org.freedesktop.Notifications \
        --object-path /org/freedesktop/Notifications \
        --method org.freedesktop.Notifications.Notify \
        qshell 0 "$icon" "$summary" "$body" \
        "[]" "{}" "$timeout" >/dev/null
}

# Let the shell know a capture finished, so it stops hiding its own UI. Silent
# no-op when the shell isn't running.
capture_done() {
    qs -c qshell ipc call capture done >/dev/null 2>&1 || true
}
