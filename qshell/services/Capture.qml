pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screenshots and screen recording (grim / slurp / wf-recorder), plus the
// region geometry the dim overlay needs while an area recording is live.
//
// Region selection runs slurp from here rather than inside a shell one-liner
// so the geometry comes back into QML — the overlay can't dim "everything
// except the recording" without knowing where the recording is.
Singleton {
    id: root

    readonly property string shotDir: `${Quickshell.env("HOME")}/Pictures/Screenshots`
    readonly property string videoDir: `${Quickshell.env("HOME")}/Videos`

    property bool recording: false
    // "x,y wxh" as slurp prints it; empty for a full-screen recording.
    property string regionGeom: ""

    readonly property int rx: parseGeom(0)
    readonly property int ry: parseGeom(1)
    readonly property int rw: parseGeom(2)
    readonly property int rh: parseGeom(3)

    readonly property bool regionRecording: recording && regionGeom !== ""

    function parseGeom(i: int): int {
        const m = root.regionGeom.match(/^(-?\d+),(-?\d+)\s+(\d+)x(\d+)$/);
        return m ? parseInt(m[i + 1], 10) : 0;
    }

    // Posts a notification with Open / Show-in-folder buttons, as a shell
    // snippet to be embedded where `$f` holds the path.
    //
    // gdbus rather than notify-send: notify-send's own --action support makes
    // it sit in a glib loop waiting for the click, then hands the key back over
    // DBus — and it exits when the notification expires, so the buttons are
    // dead a few seconds later when you find the card in the notification
    // center. Posting the raw Notify call returns immediately and leaves the
    // actions to the shell (Notifs.runAction), where they keep working for as
    // long as the notification exists.
    //
    // The body is deliberately the bare path: that's what the actions operate
    // on, so what the card shows and what the buttons do can't disagree.
    function notifySnippet(summary: string, icon: string): string {
        return `
            gdbus call --session --dest org.freedesktop.Notifications \
                --object-path /org/freedesktop/Notifications \
                --method org.freedesktop.Notifications.Notify \
                qshell 0 "${icon}" "${summary}" "$f" \
                "['qshell-open','Open','qshell-reveal','Show in folder']" \
                "{}" 8000 >/dev/null
        `;
    }

    // ── Screenshots ──
    // Each mode ends the same way: write the png, copy it, notify with actions
    // to open it. Only the geometry differs.
    function shoot(mode: string): void {
        const f = `${root.shotDir}/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png`;
        let geom = "";
        if (mode === "area")
            geom = `-g "$(slurp)" `;
        else if (mode === "window")
            geom = `-g "$(hyprctl -j activewindow | jq -r '"\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])"')" `;

        // slurp exits non-zero when the selection is cancelled — `set -e` keeps
        // that from producing an empty screenshot and a bogus notification.
        Quickshell.execDetached(["sh", "-c", `
            set -e
            mkdir -p '${root.shotDir}'
            f="${f}"
            grim ${geom}"$f"
            wl-copy < "$f"
            ${root.notifySnippet("Screenshot saved", "$f")}
        `]);
    }

    // ── Recording ──
    function recordFull(): void {
        root.regionGeom = "";
        startRecorder("");
    }

    // Two steps: pick the region (so QML learns the geometry and can dim
    // around it), then start the recorder on it.
    function recordArea(): void {
        picker.running = false;
        picker.running = true;
    }

    function startRecorder(geom: string): void {
        const g = geom ? `-g "${geom}" ` : "";
        Quickshell.execDetached(["sh", "-c", `
            mkdir -p '${root.videoDir}'
            wf-recorder ${g}--audio="$(pactl get-default-sink).monitor" \
                -f '${root.videoDir}'/recording_$(date +%Y-%m-%d_%H-%M-%S).mp4 \
                >/dev/null 2>&1
        `]);
        poll.restart();
    }

    function stopRecording(): void {
        Quickshell.execDetached(["pkill", "-INT", "-x", "wf-recorder"]);
        root.regionGeom = "";
        poll.restart();
    }

    function toggleRecording(): void {
        if (recording)
            stopRecording();
        else
            recordArea();
    }

    Process {
        id: picker

        command: ["slurp"]

        stdout: StdioCollector {
            onStreamFinished: {
                const g = text.trim();
                if (!g)
                    return; // cancelled
                root.regionGeom = g;
                root.startRecorder(g);
            }
        }
    }

    // wf-recorder is launched detached, so its liveness is the source of truth
    // for `recording` — including when it's stopped from outside the shell.
    Timer {
        id: poll

        running: true
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }

    Process {
        id: probe

        command: ["sh", "-c", "pgrep -x wf-recorder >/dev/null && echo yes || echo no"]

        stdout: StdioCollector {
            onStreamFinished: {
                const was = root.recording;
                root.recording = text.trim() === "yes";
                if (was && !root.recording) {
                    root.regionGeom = "";
                    Quickshell.execDetached(["sh", "-c", `
                        f=$(ls -t '${root.videoDir}'/recording_*.mp4 2>/dev/null | head -1)
                        [ -n "$f" ] || exit 0
                        printf %s "$f" | wl-copy
                        ${root.notifySnippet("Recording saved", "video-x-generic")}
                    `]);
                }
            }
        }
    }
}
