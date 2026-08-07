#!/usr/bin/bash
# Read a screen region: OCR its text, or decode a QR/barcode in it. Either way
# the answer goes to the clipboard and a notification says what happened.
#
#   usage: ocr.sh [text|qr] [geometry]
#
# The geometry argument is optional and exists so this can be tested without a
# human dragging a rectangle: pass slurp's format ("X,Y WxH", global compositor
# coordinates) and the selection step is skipped.
#
# Driven by qshell (services/Capture.qml -> `qs ipc call capture ocr|qr`), which
# hides the bar and any live toast first — they are on the screen being read, and
# not hiding them OCRs the shell's own UI into your clipboard. Cancelling the
# selection (Esc / right-click) exits cleanly.

mode="${1:-text}"
geom="${2:-}"

# shellcheck source=lib/capture.sh
. "$(dirname "$(readlink -f "$0")")/lib/capture.sh"

# Report back on EVERY path out — success, cancellation, failure mid-script — so
# the shell stops hiding its own UI. Same convention as screenshot.sh.
trap capture_done EXIT

if [ -z "$geom" ]; then
    geom="$(slurp)" || exit 0
fi
[ -n "$geom" ] || exit 0

# ── how much to supersample ──────────────────────────────────────────────────
# grim's -s is an ABSOLUTE output scale, not a multiplier, and its default is
# already the greatest scale of the outputs being captured. Measured here: a
# 1300x300 logical region comes out 1733x400 by default on a scale-1.33 monitor,
# and 2600x600 at `-s 2`. So a hardcoded `-s 2` is only 1.5x native here and
# would be a *downscale* on a 2x display — the opposite of the intent.
#
# Supersampling is not a nicety. At native scale tesseract turned a line of 12pt
# terminal text into "faiiged Wds Ld4L4lo Lk juusl vianuing"; at 2x the same line
# came back verbatim.
#
# The budget matters as much as the factor: tesseract is roughly linear in pixel
# count and holds the whole page in memory, so an unbounded upscale of a
# full-screen selection is a multi-second stall for no accuracy gain. Cap the
# output at ~8MP and let big selections have a smaller factor.
scale="$(hyprctl -j monitors 2>/dev/null | jq -r 'map(select(.focused))[0].scale // 1')"
case "$scale" in ''|null) scale=1 ;; esac

# "X,Y WxH" -> W and H (logical pixels)
wh="${geom##* }"
gw="${wh%x*}"
gh="${wh#*x}"

factor="$(awk -v s="$scale" -v w="$gw" -v h="$gh" 'BEGIN {
    budget = 8000000
    want = s * 2                       # 2x the monitor s native pixel density
    if (w > 0 && h > 0) {
        cap = sqrt(budget / (w * h))
        if (cap < want) want = cap
    }
    if (want < s) want = s             # never below native; that only loses detail
    printf "%.2f", want
}')"

case "$mode" in
text)
    # No temp file: grim writes PNG to stdout, tesseract reads "-" from stdin.
    # A cancelled or crashed run leaves nothing behind to clean up.
    #
    # --psm 6 is "one uniform block of text". --psm 4 (single column) measured
    # identically on screen regions, so this is the tested choice rather than a
    # strong opinion.
    text="$(grim -s "$factor" -g "$geom" - 2>/dev/null | tesseract - - --psm 6 2>/dev/null)"

    # Command substitution has already stripped trailing newlines; this asks
    # whether anything but whitespace survived, because tesseract answers a
    # blank region with blank lines rather than with silence.
    if ! printf '%s' "$text" | grep -q '[^[:space:]]'; then
        notify_plain "No text found" "Nothing legible in that region" "text-x-generic" 4000
        exit 0
    fi

    # wl-copy daemonises and inherits our stdout — see lib/capture.sh. Hand it
    # clean fds or anything reading this script waits on a process meant to
    # outlive it. The clipboard gets the text whole; only the preview is cut.
    printf '%s' "$text" | wl-copy >/dev/null 2>&1

    lines="$(printf '%s' "$text" | grep -c .)"
    # Truncate for the toast by CHARACTERS, not bytes: bash substring expansion
    # would happily split a multi-byte character, and gdbus rejects invalid
    # UTF-8 — which does not mangle the notification, it means no notification
    # appears at all. `cut -c` is multibyte-aware in this UTF-8 locale.
    #
    # `<` goes because Qt's Text defaults to AutoText, which switches to rich
    # text when a string looks like markup and would silently swallow the rest
    # of the preview.
    preview="$(printf '%s' "$text" | tr -d '<' | cut -c1-400)"
    [ "$(printf '%s' "$text" | wc -m)" -gt 400 ] && preview="$preview…"

    notify_plain "Copied $lines line(s)" "$preview" "text-x-generic" 6000
    ;;
qr)
    # No supersampling: zbarimg wants the pixels as they are, and grim already
    # captures at the output's native resolution rather than the logical one.
    #
    # The usual reason this finds nothing is a selection that clipped the code's
    # quiet zone — a QR without its margin does not decode. The message says
    # "in that region" for exactly that case.
    data="$(grim -g "$geom" - 2>/dev/null | zbarimg --raw -q - 2>/dev/null)"
    if [ -z "$data" ]; then
        notify_plain "No code found" "Nothing scannable there — include the code's white margin" "image-x-generic" 4000
        exit 0
    fi
    printf '%s' "$data" | wl-copy >/dev/null 2>&1
    notify_plain "Code copied" "$(printf '%s' "$data" | tr -d '<' | cut -c1-400)" "image-x-generic" 6000
    ;;
*)
    echo "usage: $0 [text|qr] [geometry]" >&2
    exit 1
    ;;
esac
