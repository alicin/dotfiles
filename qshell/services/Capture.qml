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

    // Region picked but not rolling yet. Selecting an area and *immediately*
    // recording meant the first seconds were always you letting go of the mouse
    // and getting out of the way, so the selection now only arms it — the
    // overlay puts a Start button on screen and you begin when you're ready.
    readonly property bool armed: regionGeom !== "" && !recording

    // Audio sources to mix in. Persisted, because this is a preference about
    // how you record rather than a per-clip decision.
    readonly property bool recordSystem: persist.recordSystem
    readonly property bool recordMic: persist.recordMic

    function toggleSystem(): void {
        persist.recordSystem = !persist.recordSystem;
    }

    function toggleMic(): void {
        persist.recordMic = !persist.recordMic;
    }

    PersistentProperties {
        id: persist

        reloadableId: "qshellCapture"

        property bool recordSystem: true
        property bool recordMic: false
    }

    // Wall-clock ms when the recorder came up, and a ticking `now` so the
    // overlay can show elapsed time. `now` only advances while recording, so
    // the binding is idle the rest of the time.
    property real recordingSince: 0
    property real now: 0

    readonly property int elapsed: recording && recordingSince > 0 ? Math.max(0, Math.floor((now - recordingSince) / 1000)) : 0

    readonly property string elapsedText: {
        const t = root.elapsed;
        const m = Math.floor(t / 60);
        const s = t % 60;
        return `${m}:${s < 10 ? "0" : ""}${s}`;
    }

    // True from the moment a capture is asked for until the frame is taken.
    // Toasts key off this (Notifs.popupsHidden).
    property bool hidingUi: false

    // A selection or grab is in flight. Second requests are refused rather
    // than stacked: two slurps both take a layer-shell grab, input goes to
    // whichever ended up on top, and the other sits there forever holding the
    // screen hostage — which is what "rec area does nothing" turned out to be.
    property bool busy: false

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
    // actually unmapped it. 450ms covers the popout's 300ms close animation
    // plus the `qshell:.*` layer-rule fade on top of it — go earlier and the
    // selector comes up while the focus grab is still live, which is the same
    // failure as not closing the popout at all.
    function withUiHidden(fn: var): void {
        if (root.busy)
            return;
        root.busy = true;
        root.hidingUi = true;
        root.closePopouts();
        Osd.hide();
        settle.pending = fn;
        settle.restart();
    }

    // Called from the capture script's EXIT trap, so it runs on *every* path
    // out — success, a cancelled selection, a failure mid-script.
    function finished(): void {
        root.busy = false;
        root.hidingUi = false;
        deadman.stop();
    }

    // The geometry an area recording was drawn on, handed back by the script.
    // Arms only — the overlay's Start button does the rest.
    function region(geom: string): void {
        root.regionGeom = geom;
    }

    // Throw away an armed region without recording it.
    function disarm(): void {
        if (!root.recording)
            root.regionGeom = "";
    }

    function startArmed(): void {
        if (root.armed)
            root.startRecorder(root.regionGeom);
    }

    // The capture scripts. They are the implementation — grim, slurp,
    // wf-recorder, the notification, the EXIT trap that reports back here — and
    // the Ctrl+Shift+4/5 binds run the same ones, so a capture behaves
    // identically whether it came from this menu or from the keyboard. What
    // stays on this side is only what needs the shell: getting the UI out of
    // the picture first, the countdown OSD, and the dim overlay's geometry.
    //
    // Absolute path because the config is reached through a symlink
    // (~/.config/quickshell/qshell), so Quickshell.shellDir points at the link
    // and not at the repo the scripts live in. Same convention hypr's apps.lua
    // uses for these.
    readonly property string scriptsDir: `${Quickshell.env("HOME")}/labs/dotfiles/scripts`

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
        root.run(`'${root.scriptsDir}/screenshot.sh' ${mode}`);
    }

    // ── Recording ──
    function recordFull(): void {
        root.regionGeom = "";
        root.withUiHidden(() => root.startRecorder(""));
    }

    // Two steps: pick the region (so QML learns the geometry and can dim
    // around it), then start the recorder on it. The picker only gets input
    // once the popout's focus grab is gone, hence withUiHidden.
    //
    // slurp runs inside the script and hands the geometry back over IPC, rather
    // than being its own Quickshell Process. Same path the screenshots use, and
    // that one is demonstrably interactive — a bare `Process { command:
    // ["slurp"] }` came up and drew nothing you could click.
    function recordArea(): void {
        root.withUiHidden(() => root.run(`
            g=$('${root.scriptsDir}/screen_record.sh' region) || exit 0
            [ -n "$g" ] || exit 0
            qs -c qshell ipc call capture region "$g" >/dev/null 2>&1
        `));
    }

    // The audio prefs are the shell's (they're toggles on the overlay), so they
    // travel as flags — mixing desktop + mic through a null sink is the
    // script's problem, and the keybind gets the same behaviour by passing the
    // same flags.
    function startRecorder(geom: string): void {
        const g = geom ? ` -g '${geom}'` : "";
        let audio = " --no-audio";
        if (root.recordSystem && root.recordMic)
            audio = " --system --mic";
        else if (root.recordSystem)
            audio = " --system";
        else if (root.recordMic)
            audio = " --mic";

        Quickshell.execDetached(["sh", "-c", `'${root.scriptsDir}/screen_record.sh' start${g}${audio}`]);
        poll.restart();
    }

    // Through the script rather than a bare pkill, so a recording stopped from
    // the overlay announces the file the same way one stopped from the keyboard
    // does — the notification is the only thing that tells you where it went.
    function stopRecording(): void {
        Quickshell.execDetached(["sh", "-c", `'${root.scriptsDir}/screen_record.sh' stop`]);
        root.regionGeom = "";
        poll.restart();
    }

    function toggleRecording(): void {
        if (recording)
            stopRecording();
        else if (armed)
            startArmed();
        else
            recordArea();
    }

    // Detached, deliberately. These scripts block on slurp for as long as the
    // selection takes, and a tracked Process gets killed the moment the next
    // capture starts — which doesn't kill its slurp child, so the orphan stays
    // up stealing clicks from the new one. The EXIT trap is what reports back
    // instead.
    function run(script: string): void {
        Quickshell.execDetached(["sh", "-c", script]);
        deadman.restart();
    }

    // If a script dies without its trap running, the shell would hide its own
    // toasts forever. Long enough not to cut a real selection short.
    Timer {
        id: deadman

        interval: 120000
        onTriggered: root.finished()
    }

    Timer {
        id: settle

        property var pending: null

        interval: 450
        onTriggered: {
            const fn = settle.pending;
            settle.pending = null;
            if (fn)
                fn();
        }
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

    // Drives `now` while recording, for the overlay's elapsed counter.
    Timer {
        running: root.recording
        interval: 500
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }

    Process {
        id: probe

        command: ["sh", "-c", "pgrep -x wf-recorder >/dev/null && echo yes || echo no"]

        stdout: StdioCollector {
            onStreamFinished: {
                const was = root.recording;
                root.recording = text.trim() === "yes";
                // Timed from when the recorder is first *seen*, not from when
                // it was asked for: wf-recorder takes a moment to come up, and
                // counting that in would overstate the clip's length.
                if (!was && root.recording) {
                    root.recordingSince = Date.now();
                    root.now = root.recordingSince;
                }
                if (was && !root.recording) {
                    root.recordingSince = 0;
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
