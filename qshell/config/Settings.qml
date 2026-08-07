pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Live settings, backed by <shell root>/settings.json. The file is watched, so
// editing it (or `qs -c qshell ipc call theme set <name>`) applies instantly.
//
// Writes go out the same door: a setter assigns to the JsonAdapter and
// Quickshell serialises the whole file back. That is free for a switch — one
// tap, one write — but a slider emits on every frame it moves under a finger,
// and rewriting (and re-watching, and re-parsing) settings.json sixty times a
// second is both wasteful and the classic way to read back a half-written
// file. So numeric setters stage the value in memory, where every binding
// below picks it up on the next frame, and the file catches up once the
// gesture stops. Same shape as the `settle` timers in services/Displays.qml
// and services/Brightness.qml, pointed the other way: those delay a *read*
// until the world stops moving, this delays a *write* until the finger does.
Singleton {
    id: root

    // Values a setter has accepted but not yet committed to the file. Empty
    // except during a drag and for one interval afterwards.
    property var staged: ({})

    // True once settings.json has actually been read (or found missing and
    // seeded). Consumers that must not act on the adapter DEFAULTS — like
    // ThemeSync, which treats default→saved as a real theme change and
    // re-themed four programs on every login — gate on this.
    property bool ready: false

    // One settings.json is shared by three machines whose compositors define
    // different workspace counts (k3v1n 9, mcu 10, h4l9000 12), so a single
    // `workspaces` number cannot be right everywhere. `workspacesByHost` pins
    // each known host; plain `workspaces` is the fallback for anything else.
    readonly property string hostname: (hostFile.text() || "").trim()

    readonly property string theme: adapter.theme
    // Clamped on the read path like scrollFactor below, not just in the
    // setters: settings.json is a documented live-edit surface, and a reload
    // feeds the adapter straight into these properties without any setter
    // running. `overviewColumns: 0` from a hand-edit reached Overview's
    // ceil(workspaces / columns) as a division by zero.
    readonly property int workspaces: Math.max(1, Math.min(20, root.staged.workspaces ?? adapter.workspacesByHost[root.hostname] ?? adapter.workspaces))
    readonly property int launcherMaxShown: Math.max(1, Math.min(20, root.staged.launcherMaxShown ?? adapter.launcherMaxShown))
    readonly property real scale: root.staged.scale ?? adapter.scale
    readonly property int overviewColumns: Math.max(1, Math.min(12, root.staged.overviewColumns ?? adapter.overviewColumns))
    // Multiplies trackpad scrolling inside the shell's lists only.
    // Clamped so a bad edit can't make lists unscrollable or uncontrollable.
    readonly property real scrollFactor: Math.max(0.25, Math.min(10, root.staged.scrollFactor ?? adapter.scrollFactor))

    // Global motion multiplier over every Appearance duration token. 0 is
    // "reduced motion": animations resolve in the same frame instead of being
    // removed, so nothing has to grow a second, non-animated code path.
    // Capped at 3 — beyond that the shell stops feeling responsive at all.
    readonly property real animScale: Math.max(0, Math.min(3, root.staged.animScale ?? adapter.animScale))

    // Weather in the calendar popout. Off means nothing is ever fetched.
    // `weatherPlace` is "lat,lon"; empty asks for a one-time coarse IP lookup.
    readonly property bool weather: adapter.weather
    readonly property string weatherPlace: adapter.weatherPlace

    // Suspend the machine when the battery gets critical rather than letting
    // it die mid-write. See services/Power.qml for the thresholds.
    readonly property bool batteryCriticalSuspend: adapter.batteryCriticalSuspend

    // What the launcher's `!` mode opens when asked to run something in a
    // terminal, and what a "Run in terminal" row spawns.
    readonly property string terminal: adapter.terminal

    // Clipboard picker: paste straight into the window you came from instead
    // of only loading the selection onto the clipboard.
    readonly property bool clipboardPaste: adapter.clipboardPaste

    // Terminals take Ctrl+Shift+V, everything else Ctrl+V — matched against
    // the window class the picker was opened over. A regex so a new terminal
    // is one settings edit, not a code change.
    readonly property string clipboardPasteTerminals: adapter.clipboardPasteTerminals

    // ── Touch / tablet ──
    // "auto" resolves from hardware (services/Tablet.qml): a detached keyboard
    // or a hinge folded past the tablet-mode switch. "tablet"/"desktop" pin it,
    // which is what you want on a machine with neither signal — every other
    // host in this repo answers "desktop" to both questions forever.
    //
    // Normalised on the READ path, like the numeric clamps above: the setters
    // already sanitise, but a hand-edit of settings.json ("On", "of") reaches
    // these straight from the reload — and Osk.wanted tests exact strings, so
    // an unrecognised mode was a keyboard that never rose while the helper
    // kept holding the seat's one input-method slot.
    readonly property string tabletMode: ["auto", "tablet", "desktop"].includes(adapter.tabletMode) ? adapter.tabletMode : "auto"

    // Written by services/Tablet.qml, never persisted: it is the *resolved*
    // answer to the above, and a stale one restored from disk at boot would
    // put the shell in touch mode on a docked machine until the helper's first
    // line arrived. Lives here rather than on Appearance because qs.config must
    // not import qs.services — every service already imports qs.config, and a
    // QML singleton import cycle fails in ways that are miserable to debug.
    property bool touchActive: false

    // Multiplied into Appearance.scale while touch mode is on, so every s()
    // call site in the shell grows without a single edit. 1.25 is roughly the
    // step from "pointer" to "fingertip" — a 34px bar pill becomes 43px, which
    // clears the ~9mm target a thumb actually needs at this panel's DPI.
    readonly property real touchScale: Math.max(1, Math.min(2, root.staged.touchScale ?? adapter.touchScale))

    // On-screen keyboard. "auto" = only when no physical keyboard is attached,
    // which is the whole point: this is a convertible, and a keyboard that
    // appears over a docked session is the exact thing squeekboard was removed
    // for (see config/hypr/lua/hosts/k3v1n.lua). Read-path normalised — see
    // tabletMode above.
    readonly property string osk: ["auto", "on", "off"].includes(adapter.osk) ? adapter.osk : "auto"

    // Fraction of the screen height the keyboard claims. It becomes the layer
    // surface's exclusive zone, so it is also how much the tiled layout gives
    // up — bounded well short of half the screen for that reason.
    readonly property real oskHeight: Math.max(0.2, Math.min(0.5, root.staged.oskHeight ?? adapter.oskHeight))

    // Rotation lock. Inert on k3v1n (its AMD sensor hub exposes an ambient
    // light sensor and no accelerometer at all, so nothing ever rotates it),
    // but it is the gate the orientation listener checks, so autorotate starts
    // behaving correctly the day a sensor exists rather than needing new code.
    readonly property bool rotationLock: adapter.rotationLock

    // Touchscreen edge swipes (bottom → launcher/keyboard, left → overview,
    // right → Control Center). Off on a desktop, where the "edges" are just
    // pixels a mouse crosses on its way somewhere else.
    readonly property bool edgeSwipes: adapter.edgeSwipes

    // ── Setters ──
    // Every numeric one clamps rather than trusting its caller. The Settings
    // page's controls are already bounded, but these are also the surface an
    // IPC handler or a keybind would drive, and several of them can strand
    // you: scale 5 makes a 340px panel wider than a 1080p screen, and
    // workspaces 0 leaves the bar with nothing on it at all. The bounds here
    // are the *valid* range; the page picks a comfortable sub-range of it.

    function setTheme(name: string): void {
        adapter.theme = name;
    }

    // Matches the clamp Appearance applies when it reads this back — a setter
    // that can store a value the reader will ignore is just a bug with extra
    // steps.
    function setScale(v: real): void {
        root.stage("scale", Math.max(0.5, Math.min(2.5, v)));
    }

    function setAnimScale(v: real): void {
        root.stage("animScale", Math.max(0, Math.min(3, v)));
    }

    function setScrollFactor(v: real): void {
        root.stage("scrollFactor", Math.max(0.25, Math.min(10, v)));
    }

    // 20 is not a Hyprland limit — it is where the bar stops being a bar. Each
    // workspace is a ~22px slot (Appearance.sizes.slotEmpty), so twenty of
    // them already claim half the width of this laptop's 2560px panel.
    //
    // Writes the per-host entry when this host has one (see workspacesByHost)
    // — staging into the shared `workspaces` would look like a dead stepper
    // here, since the per-host value wins on the read path. Direct write, no
    // staging: a stepper is discrete taps, not a slider drag.
    function setWorkspaces(n: int): void {
        const v = Math.max(1, Math.min(20, n));
        if (adapter.workspacesByHost[root.hostname] !== undefined)
            adapter.workspacesByHost[root.hostname] = v;
        else
            root.stage("workspaces", v);
    }

    // The launcher sizes its window to this count (Launcher.qml computes
    // implicitHeight from it), so it is a window height, not a scroll cap: 20
    // rows at 56px each is already taller than a 1080p screen.
    function setLauncherMaxShown(n: int): void {
        root.stage("launcherMaxShown", Math.max(1, Math.min(20, n)));
    }

    // Overview derives its row count as ceil(workspaces / columns), which is
    // an infinity at zero.
    function setOverviewColumns(n: int): void {
        root.stage("overviewColumns", Math.max(1, Math.min(12, n)));
    }

    function setWeather(on: bool): void {
        adapter.weather = on;
    }

    // Stored verbatim; services/Weather.qml passes it to the geocoder as an
    // argument, never interpolated into the shell script, so an odd string is
    // a failed lookup rather than anything worse. The page still validates the
    // "lat,lon" shape, because a silently failing lookup is its own bad time.
    function setWeatherPlace(place: string): void {
        adapter.weatherPlace = place;
    }

    function setBatteryCriticalSuspend(on: bool): void {
        adapter.batteryCriticalSuspend = on;
    }

    // Goes out as argv[0] of an execDetached (services/Search.qml), so it is
    // one executable, not a command line — "kitty", never "kitty --hold".
    function setTerminal(cmd: string): void {
        adapter.terminal = cmd;
    }

    function setClipboardPaste(on: bool): void {
        adapter.clipboardPaste = on;
    }

    // Not validated here, deliberately: "compiles as a regular expression" is
    // a question with a try/catch answer, and the caller is the one holding the
    // text the user is still editing. The Settings page's field checks it and
    // refuses to call this; a `settings` IPC that skips the check gets exactly
    // what it asked for.
    function setClipboardPasteTerminals(re: string): void {
        adapter.clipboardPasteTerminals = re;
    }

    // Anything unrecognised means "auto" rather than nothing: these two are
    // driven by a cycling bar button and a settings row, and a typo that left
    // the shell in no mode at all would be a blank keyboard and a bar with a
    // dead toggle on it.
    function setTabletMode(mode: string): void {
        adapter.tabletMode = ["auto", "tablet", "desktop"].includes(mode) ? mode : "auto";
    }

    function setOsk(mode: string): void {
        adapter.osk = ["auto", "on", "off"].includes(mode) ? mode : "auto";
    }

    function setTouchScale(v: real): void {
        root.stage("touchScale", Math.max(1, Math.min(2, v)));
    }

    function setOskHeight(v: real): void {
        root.stage("oskHeight", Math.max(0.2, Math.min(0.5, v)));
    }

    function setRotationLock(on: bool): void {
        adapter.rotationLock = on;
    }

    function setEdgeSwipes(on: bool): void {
        adapter.edgeSwipes = on;
    }

    function stage(key: string, value: real): void {
        // Reassigned wholesale instead of mutated: writing into the existing
        // object changes no QML property, so nothing bound to `staged`
        // re-evaluates and the control sits at its old position until the
        // commit lands — which is exactly the lag the staging exists to avoid.
        //
        // Rounded on the way in because a slider step lands on values like
        // 1.1500000000000001, and settings.json is a file people read and
        // hand-edit. Three decimals is finer than any step the page offers.
        const next = Object.assign({}, root.staged);
        next[key] = Math.round(value * 1000) / 1000;
        root.staged = next;
        commit.restart();
    }

    // 220ms after the last movement. A slider under a finger updates every
    // frame (~16ms) and a wheel notch repeats far faster than this, so any
    // real gesture coalesces into one write; it is still short enough that
    // letting go and immediately reloading the shell catches the new value.
    Timer {
        id: commit

        interval: 220
        onTriggered: {
            for (const key in root.staged)
                adapter[key] = root.staged[key];
            // Cleared only after the assignments, so the bindings above never
            // see a frame where the staged value is gone and the adapter has
            // not caught up — that gap would flash the old value.
            root.staged = ({});
        }
    }

    // The machine's name, for workspacesByHost. blockLoading: it is a
    // ten-byte file, and every binding above would otherwise race the load.
    FileView {
        id: hostFile

        path: "/etc/hostname"
        blockLoading: true
    }

    FileView {
        path: Quickshell.shellPath("settings.json")
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoaded: root.ready = true
        // Seed a missing file, but never clobber one that failed to read for
        // any other reason (permissions, a mid-edit swap-file dance): the
        // watcher exists to support hand-edits, and "transient read error →
        // shell rewrites the file with its in-memory state" silently reverts
        // the very edit being made. Same guard Apps.qml uses.
        onLoadFailed: error => {
            root.ready = true;
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        adapter: JsonAdapter {
            id: adapter

            property string theme: "catppuccin-latte"
            property int workspaces: 12
            property JsonObject workspacesByHost: JsonObject {
                property int k3v1n: 9
                property int h4l9000: 12
                property int mcu: 10
            }
            property int launcherMaxShown: 8
            property real scale: 1.15
            property int overviewColumns: 6
            property real scrollFactor: 3.5
            property real animScale: 1
            property bool weather: true
            property string weatherPlace: ""
            property bool batteryCriticalSuspend: true
            property string terminal: "ghostty"
            property bool clipboardPaste: false
            property string clipboardPasteTerminals: "ghostty|floating_shell|kitty|foot|alacritty|wezterm|konsole|terminator|xterm|st"
            property string tabletMode: "auto"
            property real touchScale: 1.25
            property string osk: "auto"
            property real oskHeight: 0.32
            property bool rotationLock: false
            property bool edgeSwipes: true
        }
    }
}
