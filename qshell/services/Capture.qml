pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screenshots and screen recording (grim / slurp / wf-recorder), plus the
// region geometry the dim overlay needs while an area recording is live.
//
// Every capture starts by getting the shell out of the way. Popouts, toasts and
// the OSD all live on the wayland *overlay* layer, so grim photographs them —
// and worse, a popout holding a HyprlandFocusGrab swallows the first click
// meant for slurp, which is why "Rec area" appeared to do nothing at all: the
// selector came up behind a grab and never saw the press that would have
// started the recording.
//
// Region selection runs slurp from here rather than inside a shell one-liner so
// the geometry comes back into QML — the overlay can't dim "everything except
// the recording" without knowing where the recording is.
Singleton {
    id: root

    readonly property string shotDir: `${Quickshell.env("HOME")}/Pictures/Screenshots`
    readonly property string videoDir: `${Quickshell.env("HOME")}/Videos`

    property bool recording: false
    // "x,y wxh" as slurp prints it; empty for a full-screen recording.
    property string regionGeom: ""

    // True from the moment a capture is asked for until the frame is taken.
    // Toasts key off this (Notifs.popupsHidden).
    property bool hidingUi: false

    // Popouts listen for this and close.
    signal closePopouts

    // Seconds left before a full-screen grab; 0 when not counting.
    property int countdown: 0

    readonly property int rx: parseGeom(0)
    readonly property int ry: parseGeom(1)
    readonly property int rw: parseGeom(2)
    readonly property int rh: parseGeom(3)

    readonly property bool regionRecording: recording && regionGeom !== ""

    function parseGeom(i: int): int {
        const m = root.regionGeom.match(/^(-?\d+),(-?\d+)\s+(\d+)x(\d+)$/);
        return m ? parseInt(m[i + 1], 10) : 0;
    }

    // Clear the shell off the screen, then run `fn` once the compositor has
    // actually unmapped it. 350ms covers the popout's 300ms close animation —
    // shooting earlier catches it mid-fade.
    function withUiHidden(fn: var): void {
        root.hidingUi = true;
        root.closePopouts();
        Osd.hide();
        settle.pending = fn;
        settle.restart();
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

    // area   — freehand region (slurp)
    // window — pick a window: slurp -r restricted to the boxes of everything
    //          visible, so hovering highlights a whole window and clicking
    //          takes exactly it. Beats grabbing `activewindow`, which is
    //          whatever had focus before the Control Center did.
    // full   — whole screen, after a 3-second countdown, because the thing you
    //          want to photograph is usually not reachable while a menu is open.
    function shoot(mode: string): void {
        if (mode === "full") {
            root.withUiHidden(() => {
                root.countdown = 3;
                Osd.show("countdown");
                ticker.restart();
            });
            return;
        }
        root.withUiHidden(() => root.grab(mode));
    }

    function grab(mode: string): void {
        let geom = "";
        if (mode === "area") {
            geom = `-g "$(slurp)" `;
        } else if (mode === "window") {
            // Boxes for mapped, non-hidden windows on whichever workspaces are
            // currently visible — one per monitor, so this stays right with
            // more than one screen.
            geom = `-g "$(
                ws=$(hyprctl -j monitors | jq -c '[.[].activeWorkspace.id]')
                hyprctl -j clients | jq -r --argjson ws "$ws" '
                    .[] | select(.mapped and (.hidden | not)
                                 and (.workspace.id as $i | $ws | index($i)))
                    | "\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])"' \
                    | slurp -r -f '%x,%y %wx%h'
            )" `;
        }

        // slurp exits non-zero when the selection is cancelled — `set -e` keeps
        // that from producing an empty screenshot and a bogus notification.
        root.run(`
            set -e
            mkdir -p '${root.shotDir}'
            f="${root.shotDir}/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"
            grim ${geom}"$f"
            wl-copy < "$f"
            ${root.notifySnippet("Screenshot saved", "$f")}
        `);
    }

    // ── Recording ──
    function recordFull(): void {
        root.regionGeom = "";
        root.withUiHidden(() => root.startRecorder(""));
    }

    // Two steps: pick the region (so QML learns the geometry and can dim
    // around it), then start the recorder on it. The picker only gets input
    // once the popout's focus grab is gone, hence withUiHidden.
    function recordArea(): void {
        root.withUiHidden(() => {
            picker.running = false;
            picker.running = true;
        });
    }

    function startRecorder(geom: string): void {
        const g = geom ? `-g "${geom}" ` : "";
        Quickshell.execDetached(["sh", "-c", `
            mkdir -p '${root.videoDir}'
            wf-recorder ${g}--audio="$(pactl get-default-sink).monitor" \
                -f '${root.videoDir}'/recording_$(date +%Y-%m-%d_%H-%M-%S).mp4 \
                >/dev/null 2>&1
        `]);
        root.hidingUi = false;
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

    // Run a capture script. A tracked Process, not execDetached, purely so the
    // toast suppression can be lifted when the shot is actually taken rather
    // than guessed at — an area selection can sit there for half a minute.
    function run(script: string): void {
        root.script = script;
        shooter.running = false;
        shooter.running = true;
    }

    property string script: ""

    Process {
        id: shooter

        command: ["sh", "-c", root.script]
        onExited: root.hidingUi = false
    }

    Timer {
        id: settle

        property var pending: null

        interval: 350
        onTriggered: {
            const fn = root.settleFn();
            if (fn)
                fn();
        }
    }

    function settleFn(): var {
        const fn = settle.pending;
        settle.pending = null;
        return fn;
    }

    Timer {
        id: ticker

        interval: 1000
        repeat: true
        onTriggered: {
            root.countdown--;
            if (root.countdown > 0) {
                Osd.show("countdown");
                return;
            }
            ticker.stop();
            // The OSD is on the overlay layer and would be in the picture, so
            // it goes first and the shutter waits out its fade.
            Osd.hide();
            afterOsd.restart();
        }
    }

    Timer {
        id: afterOsd

        // The OSD's exit animation is 200ms; a little margin past it.
        interval: 280
        onTriggered: root.grab("full")
    }

    Process {
        id: picker

        command: ["slurp"]

        stdout: StdioCollector {
            onStreamFinished: {
                const g = text.trim();
                if (!g) {
                    root.hidingUi = false;
                    return; // cancelled
                }
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
