#!/usr/bin/bash
# Screen recording with wf-recorder, macOS Cmd+Shift+5 style: the first press
# selects a region and starts, the second stops and saves.
#
#   screen_record.sh toggle [opts]        select a region, or stop if rolling
#   screen_record.sh start [opts]         start (full screen unless -g)
#   screen_record.sh pause                pause (closes the current segment)
#   screen_record.sh resume               resume into a new segment
#   screen_record.sh stop                 stop, assemble and announce the file
#   screen_record.sh region               print a slurp selection, nothing else
#   screen_record.sh status               "recording" / "paused" / "not recording"
#
#   opts: -g "x,y wxh"   record this region instead of the whole screen
#         --system       mix in desktop audio   (default when neither is given)
#         --mic          mix in the microphone
#         --no-audio     record silent
#
# This is the only recording implementation: qshell's Control Center overlay
# runs it (services/Capture.qml) and so does the Ctrl+Shift+5 bind, which
# prefers the shell's IPC — it can dim around the region and show elapsed time —
# and falls back to running this directly when the shell isn't up.
#
# Pause is segment-based, not a signal: wf-recorder 0.6.0 installs no SIGUSR1
# handler, so the signal other recorders pause on simply kills it — and takes
# the unfinalised file with it. Pausing therefore closes the current segment
# cleanly and resuming opens the next one; `stop` concatenates them through
# ffmpeg's concat demuxer with no re-encode, so a paused take costs nothing in
# quality and only a moment of muxing.

# shellcheck source=lib/capture.sh
. "$(dirname "$(readlink -f "$0")")/lib/capture.sh"

videoDir="${videoDir:-$HOME/Videos}"
lastPath=/tmp/last_recording_path

# Per-recording scratch: the destination path, the options to resume with, and
# the segments themselves. Under the runtime dir so a reboot can't leave a
# stale session behind claiming a recording is paused.
session="${XDG_RUNTIME_DIR:-/tmp}/qshell-record"

geom=""
want_system=""
want_mic=""

checkRecording() { pgrep -x wf-recorder >/dev/null; }
checkPaused() { [ -f "$session/paused" ]; }

parseOpts() {
    while [ $# -gt 0 ]; do
        case "$1" in
        -g)
            geom="$2"
            shift 2
            ;;
        --system)
            want_system=1
            shift
            ;;
        --mic)
            want_mic=1
            shift
            ;;
        --no-audio)
            want_system=""
            want_mic=""
            no_audio=1
            shift
            ;;
        *) shift ;;
        esac
    done
    # Desktop audio is the sane default, and what this script did before it
    # learned about the mic.
    [ -z "$want_system$want_mic${no_audio:-}" ] && want_system=1
    return 0
}

# Launch wf-recorder onto the next segment file. Zero-padded so a plain sort
# keeps recording order past ten segments, which is what concat needs.
startSegment() {
    local n seg
    n=$(find "$session" -maxdepth 1 -name 'seg-*.mkv' 2>/dev/null | wc -l)
    seg=$(printf '%s/seg-%03d.mkv' "$session" "$((n + 1))")

    # An array, not a string: the geometry has a space in it ("x,y wxh"), so an
    # unquoted expansion splits it in two and wf-recorder quietly records the
    # whole screen instead of the region you selected.
    args=()
    [ -n "$geom" ] && args+=(--geometry "$geom")

    # wf-recorder takes exactly one --audio device, so recording the desktop
    # *and* the mic together needs them mixed first: a null sink with a loopback
    # from each, recorded through its monitor. The modules are torn down in an
    # EXIT trap, so a crash or a kill doesn't leave a phantom output device
    # sitting in your sound settings.
    if [ -n "$want_system" ] && [ -n "$want_mic" ]; then
        setsid -f bash -c '
            out=$1; geom=$2
            args=()
            [ -n "$geom" ] && args+=(--geometry "$geom")

            mods=""
            cleanup() { for m in $mods; do pactl unload-module "$m" 2>/dev/null; done; }
            trap cleanup EXIT INT TERM
            # Order matters: the sink has to exist before anything loops into
            # it, and it unloads last (the list is prepended to).
            m=$(pactl load-module module-null-sink sink_name=qshell_rec \
                    sink_properties=device.description=qshell-recording) || exit 1
            mods="$m"
            m=$(pactl load-module module-loopback source="$(pactl get-default-sink).monitor" \
                    sink=qshell_rec latency_msec=50) && mods="$m $mods"
            m=$(pactl load-module module-loopback source="$(pactl get-default-source)" \
                    sink=qshell_rec latency_msec=50) && mods="$m $mods"
            wf-recorder "${args[@]}" --audio=qshell_rec.monitor -f "$out" >/dev/null 2>&1
        ' _ "$seg" "$geom"
    else
        [ -n "$want_system" ] && args+=(--audio="$(pactl get-default-sink).monitor")
        [ -n "$want_mic" ] && args+=(--audio="$(pactl get-default-source)")
        setsid -f wf-recorder "${args[@]}" -f "$seg" >/dev/null 2>&1
    fi
}

# SIGINT then wait: wf-recorder needs a moment to finalise the container, and a
# segment touched before that is one that won't concatenate.
endSegment() {
    checkRecording || return 0
    pkill -INT -x wf-recorder
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        checkRecording || break
        sleep 0.2
    done
}

saveOpts() {
    printf '%s\n' "$geom" >"$session/geom"
    printf '%s\n' "$want_system" >"$session/system"
    printf '%s\n' "$want_mic" >"$session/mic"
}

loadOpts() {
    geom=$(cat "$session/geom" 2>/dev/null)
    want_system=$(cat "$session/system" 2>/dev/null)
    want_mic=$(cat "$session/mic" 2>/dev/null)
}

startRecording() {
    if checkRecording || checkPaused; then
        echo "A recording is already in progress." >&2
        exit 1
    fi

    mkdir -p "$videoDir" "$session"
    rm -f "$session"/seg-*.mkv "$session/paused"

    outputPath="$videoDir/recording_$(date +%Y-%m-%d_%H-%M-%S).mp4"
    printf '%s\n' "$outputPath" >"$session/out"
    echo "$outputPath" >"$lastPath"
    saveOpts

    startSegment
    echo "$outputPath"
}

pauseRecording() {
    checkRecording || {
        echo "No recording in progress." >&2
        exit 1
    }
    # Marker before the kill: the other order leaves a window where the shell's
    # 1s poll sees neither a recorder nor a pause, and concludes the recording
    # ended on its own.
    touch "$session/paused"
    endSegment
}

resumeRecording() {
    checkPaused || {
        echo "Not paused." >&2
        exit 1
    }
    loadOpts
    startSegment
    # Marker last, and only once wf-recorder is really up. The shell's probe
    # tests pgrep *before* the marker, so an overlap harmlessly reads "rec";
    # clearing it any earlier leaves a window where the probe sees neither and
    # concludes the take ended — which zeroes the elapsed clock and unmaps the
    # region overlay for the rest of the recording.
    #
    # Merely reordering isn't enough: startSegment is `setsid -f` and returns
    # before wf-recorder has exec'd.
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        checkRecording && break
        sleep 0.2
    done
    rm -f "$session/paused"
}

# One segment is remuxed; several are concatenated, neither re-encoded. mkv
# segments into an mp4 destination: mkv is the format that survives an
# interrupted write, and the concat demuxer is happy to remux it into mp4.
assemble() {
    local out list segs
    out=$(cat "$session/out" 2>/dev/null)
    [ -n "$out" ] || return 1

    mapfile -t segs < <(find "$session" -maxdepth 1 -name 'seg-*.mkv' -size +0 | sort)
    [ "${#segs[@]}" -gt 0 ] || return 1

    if [ "${#segs[@]}" -eq 1 ]; then
        ffmpeg -y -loglevel error -i "${segs[0]}" -c copy "$out" >/dev/null 2>&1 || return 1
    else
        list="$session/concat.txt"
        : >"$list"
        for s in "${segs[@]}"; do
            printf "file '%s'\n" "$s" >>"$list"
        done
        ffmpeg -y -loglevel error -f concat -safe 0 -i "$list" -c copy "$out" >/dev/null 2>&1 || return 1
        rm -f "$list"
    fi

    rm -f "${segs[@]}"
    printf '%s' "$out"
}

stopRecording() {
    if ! checkRecording && ! checkPaused; then
        echo "No recording in progress." >&2
        exit 1
    fi

    # Clear the pause marker first: while it exists the shell reports the
    # recording as merely paused, and it would go on saying so through the
    # whole concat.
    rm -f "$session/paused"
    endSegment

    outputPath=$(assemble)

    if [ -z "$outputPath" ] || [ ! -f "$outputPath" ]; then
        notify_plain "Recording stopped" "No recording was saved."
        exit 1
    fi

    capture_saved "$outputPath"
    notify_capture "Recording saved" "$outputPath" 10000
}

case "$1" in
start)
    shift
    parseOpts "$@"
    startRecording
    ;;
pause)
    pauseRecording
    ;;
resume)
    resumeRecording
    ;;
stop)
    stopRecording
    ;;
region)
    # Just the selection: qshell asks for this so it can dim around the region
    # and arm the overlay's Start button before anything records.
    trap capture_done EXIT
    slurp || exit 1
    ;;
toggle)
    shift
    parseOpts "$@"
    trap capture_done EXIT
    if checkRecording || checkPaused; then
        stopRecording
    else
        geom="$(slurp)" || exit 0
        [ -n "$geom" ] || exit 0
        startRecording >/dev/null
        notify_plain "Recording started" "Press the shortcut again to stop."
    fi
    ;;
status)
    if checkRecording; then
        echo recording
    elif checkPaused; then
        echo paused
    else
        echo "not recording"
    fi
    ;;
*)
    sed -n '2,30p' "$0" >&2
    exit 1
    ;;
esac
