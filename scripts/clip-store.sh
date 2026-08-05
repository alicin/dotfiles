#!/usr/bin/env bash
# Store a clipboard entry and remember which application it came from.
#
# Drop-in replacement for `cliphist store` in the two
# `wl-paste --watch` lines in hypr's startup.lua: cliphist records what was
# copied and nothing else, but the one thing a clipboard manager needs beyond
# the content is where it came from — it's how you find the thing you copied
# out of the browser twenty items ago. The focused window at the moment
# wl-paste fires IS the window that copied, so the attribution is free here
# and impossible to reconstruct later.
#
# The side store is a plain TSV under the same state dir the shell writes to:
#   <cliphist id>\t<unix seconds>\t<window class>\t<window title>
# Newest first, capped. The time is here for the same reason as the class:
# cliphist keeps no timestamps at all, so "an hour ago" is knowable only at the
# moment of the copy. qshell reads it (services/Clipboard.qml); if it is
# missing, stale or wrong, cards simply show no source and no time and
# everything else works — this must never be load-bearing.
set -euo pipefail

state="${XDG_STATE_HOME:-$HOME/.local/state}/qshell"
sources="$state/clipboard-sources.tsv"
keep=400

# The newest id cliphist knows about. awk rather than `head -1`: head closes
# the pipe on the first line, cliphist dies of SIGPIPE, and `set -o pipefail`
# then treats the whole thing as a failure.
top_id() {
    cliphist list 2>/dev/null | awk -F'\t' 'NR == 1 { print $1 }'
}

# Read *before* storing, because "what is at the top afterwards" is not the
# same question as "what did this copy store" — see the guard below.
before=$(top_id || true)

# Hand the payload to cliphist unchanged and let it be the only writer of the
# history proper — a copy that fails to store is worse than one with no
# attribution, so this happens first and its exit status is ours.
payload=$(mktemp) || exit 1
trap 'rm -f "$payload"' EXIT
cat > "$payload"
cliphist store < "$payload"

# Everything below is best-effort decoration.
mkdir -p "$state" 2>/dev/null || exit 0

id=$(top_id || true)
[ -n "${id:-}" ] || exit 0

# `cliphist store` exits 0 without storing anything for several states
# wl-paste routinely fires it in — an empty or whitespace-only selection, and
# CLIPBOARD_STATE=sensitive (a password manager) — and for
# CLIPBOARD_STATE=clear it *deletes* the newest entry instead. In every one of
# those the top of the list is some older, unrelated entry, and stamping it
# with this window and this timestamp would be an outright lie about where it
# came from. Ids are monotonic, so a strictly greater one is the proof that
# this invocation is what put it there.
case "$id" in
    '' | *[!0-9]*) exit 0 ;;
esac
case "$before" in
    '' | *[!0-9]*) before=0 ;;
esac
[ "$id" -gt "$before" ] || exit 0

win=$(hyprctl -j activewindow 2>/dev/null) || exit 0
class=$(printf '%s' "$win" | jq -r '.class // ""' 2>/dev/null) || class=""
title=$(printf '%s' "$win" | jq -r '.title // ""' 2>/dev/null) || title=""
[ -n "$class" ] || exit 0

# Tabs and newlines in a window title would forge a row; strip both.
title=$(printf '%s' "$title" | tr '\t\n' '  ' | cut -c1-120)

# Both watchers (text and image) fire for a copy that offers both, and each
# does a read-modify-write of this file — without the lock one of the two rows
# is silently dropped, which is exactly the case where attribution matters
# (an image copied out of a browser).
exec 9>"$sources.lock" || exit 0
flock -w 2 9 || exit 0

tmp=$(mktemp "$sources.XXXXXX") || exit 0
printf '%s\t%s\t%s\t%s\n' "$id" "$(date +%s)" "$class" "$title" > "$tmp"
if [ -f "$sources" ]; then
    # Re-copying something moves it back to the top under the same id, so the
    # newer attribution replaces the old row rather than joining it.
    awk -F'\t' -v id="$id" -v keep="$keep" 'NR <= keep && $1 != id' "$sources" >> "$tmp" 2>/dev/null || true
fi
mv -f "$tmp" "$sources" 2>/dev/null || rm -f "$tmp"
