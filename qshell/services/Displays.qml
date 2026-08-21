pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Monitors, for the Control Center's Display page. The layout presets and the
// eDP toggle have been keybind-only (Super+Ctrl+M/E/L, and a bare
// `disp toggle`) — invisible, unlabelled, and one of them has a known way to
// leave you with a black laptop panel and no obvious way back.
//
// Reads hyprctl rather than Quickshell.screens because it needs what the
// compositor knows and the Wayland client doesn't: which outputs exist but are
// currently *disabled*, which is exactly the set the eDP toggle moves things
// between.
Singleton {
    id: root

    // [{ name, description, width, height, refresh, scale, x, y, transform, focused, disabled }]
    property var monitors: []
    property bool polling: false

    readonly property var active: root.monitors.filter(m => !m.disabled)

    // The monitor the tablet's rotation controls act on: the focused one, or
    // the built-in panel, or whatever is left. Rotating an external desk
    // monitor because it happened to be focused is never what the button on a
    // tablet's bar means.
    readonly property var rotatable: {
        const act = root.active;
        return act.find(m => /^eDP/i.test(m.name)) ?? act.find(m => m.focused) ?? act[0] ?? null;
    }

    readonly property string summary: {
        const n = root.active.length;
        if (n === 0)
            return "…";
        if (n === 1)
            return root.active[0].name;
        return `${n} displays`;
    }

    // The screen a pinned panel should map to — by NAME, falling back to the
    // focused monitor and then to whatever is left — or null when there is no
    // real output at all.
    //
    // Every panel used to inline `Quickshell.screens.find(...) ??
    // Quickshell.screens[0] ?? null`, and that last fallback is a trap. When
    // every output goes away — `disp toggle`, a mode change, a lid-resume that
    // drops the connector — Qt keeps the process alive by fabricating a
    // PLACEHOLDER screen (`qt.qpa.wayland: There are no outputs - creating
    // placeholder screen`), and `screens[0]` hands a layer surface straight to
    // it. Quickshell says so at the time ("Layershell screen does not
    // correspond to a real screen"), the placeholder is destroyed the moment a
    // real output returns, and a PanelWindow whose screen died never maps
    // again. On 2026-08-21 one Super+Shift+M took out the launcher, the
    // clipboard picker, the OSD, the overview, notification popups and the
    // capture thumbnail in one go — every IPC call still answered "ok" and set
    // `open = true`, with no surface on screen to show for it.
    //
    // Telling the placeholder apart needs no Hyprland round-trip, so this is
    // already right on the first frame, before the IPC has answered:
    // QPlatformPlaceholderScreen overrides neither name() nor geometry(), so it
    // reports an EMPTY name and a 0x0 size, and a real wl_output can report
    // neither. Both are checked because one assumption should not be load-
    // bearing for six panels; either alone is enough to keep it out.
    //
    // An empty `name` means "the focused monitor" — that is all the callers
    // that don't pin (the PiP window, the cheat sheet) ever wanted.
    //
    // Returning null is not enough by itself: re-pointing `screen` at a live
    // output does NOT resurrect a surface the compositor already destroyed, so
    // the window has to unmap while there is nothing to map to and be rebuilt
    // when an output comes back. KeyCheat survived the same event for exactly
    // that reason — its `visible` is gated on `open`, so every open builds a
    // fresh surface. So every caller holds the answer in a property and gates
    // on THAT:
    //
    //     readonly property var realScreen: Displays.screenFor(root.pinned)
    //     screen: win.realScreen
    //     visible: win.realScreen !== null
    //
    // Gating on `win.screen` instead is a binding loop, because PanelWindow
    // reports the backing window's screen while it is visible and null when it
    // is not. Quickshell prints "Binding loop detected for property visible"
    // and then picks a side arbitrarily.
    function screenFor(name: string): var {
        const real = Quickshell.screens.filter(s => s.name !== "" && s.width > 0 && s.height > 0);
        return real.find(s => s.name === name) ?? real.find(s => s.name === Hyprland.focusedMonitor?.name) ?? real[0] ?? null;
    }

    readonly property string binDir: `${Quickshell.env("HOME")}/labs/dotfiles/bin`

    function refresh(): void {
        lister.running = true;
    }

    // Workspace-to-monitor layout is declarative now: per-host workspace
    // rules recompute from what's connected on every config reload, and the
    // host files' monitor.added/removed hooks reload automatically. This is
    // the manual nudge (Display page button, Super+Ctrl+M) for a missed
    // hotplug event — hypr-monitor-manager.sh is gone.
    function applyLayout(): void {
        Quickshell.execDetached(["hyprctl", "reload"]);
        settle.restart();
    }

    // Disabling the *only* active output is refused here rather than left to
    // the compositor: that's the footgun the toggle script is known for, and
    // the recovery is a keybind you can't read because the screen is off.
    //
    // Turning one back on goes through `hyprctl reload` rather than
    // `<name>,preferred,auto,1`: that would come up at the preferred mode,
    // auto position and scale 1, throwing away the per-host geometry in
    // config/hypr/lua/hosts/*.lua (this laptop's panel is 2560x1600@240 at
    // 1.33, and a portrait external would come back landscape). A reload drops
    // the runtime disable rule *and* re-applies the canonical layout.
    //
    // Switching off used to be `hyprctl keyword monitor <name>,disable`, which
    // has never worked on this setup and failed silently: the config is the Lua
    // parser (config/hypr/hyprland.lua), and `hyprctl keyword` answers
    // "keyword can't work with non-legacy parsers. Use eval." to everything.
    // wlr-randr goes through zwlr_output_management_v1, which Hyprland does
    // implement, and works regardless of which parser built the config.
    function setEnabled(m: var, on: bool): void {
        if (!on && root.active.length <= 1)
            return;
        if (on)
            Quickshell.execDetached(["hyprctl", "reload"]);
        else
            Quickshell.execDetached(["wlr-randr", "--output", m.name, "--off"]);
        settle.restart();
    }

    // ── Rotation ────────────────────────────────────────────────────────────
    // wl_output transform values, in the order the enum defines them, spelled
    // the way wlr-randr wants them on the command line. Hyprland reports the
    // same enum as an integer in `hyprctl -j monitors`, so the index into this
    // list *is* the monitor's current transform.
    readonly property list<string> transformNames: ["normal", "90", "180", "270", "flipped", "flipped-90", "flipped-180", "flipped-270"]

    readonly property list<string> rotationLabels: ["Landscape", "Portrait", "Landscape ↓", "Portrait ↓"]

    function setTransform(name: string, t: int): void {
        const arg = root.transformNames[t] ?? "normal";
        Quickshell.execDetached(["wlr-randr", "--output", name, "--transform", arg]);
        // Rotate touch + stylus with the picture (see the note above
        // resetRotation — the compositor does NOT do this on its own). Two
        // gates: the built-in panel only (the digitiser is bound to eDP-1 via
        // input:touchdevice:output, and rotating an external must not skew
        // it), and a touchscreen must actually exist — h4l9000's panel is
        // ALSO eDP-1, and writing global touch/tablet matrices there would
        // sit in ambush for any drawing tablet ever plugged in. transform 7
        // (flipped-270) is outside the option's 0-6 range; the rotate button
        // never produces it.
        if (/^eDP/i.test(name) && Tablet.hasTouchscreen && t <= 6)
            Quickshell.execDetached(["hyprctl", "-r", "eval", `hl.config({ input = { touchdevice = { transform = ${t} }, tablet = { transform = ${t} } } })`]);
        // Optimistically write the new transform into the cached list. A
        // transform change emits no Hyprland event, so the cache is otherwise
        // stale until the settle re-read ~900ms out — and rotate() derives the
        // *next* quarter-turn from this cache, which made two quick taps (the
        // natural gesture for a 180° flip) compute the same target and land at
        // 90°. The settle pass reconciles if wlr-randr failed.
        root.monitors = root.monitors.map(m => m.name === name ? Object.assign({}, m, {
                    transform: t
                }) : m);
        settle.restart();
    }

    // Quarter turn. Only ever cycles the four unflipped transforms: the
    // flipped ones mirror the image, which is a fix for a mispackaged panel and
    // not something a rotate button should ever hand you by accident.
    function rotate(step: int): void {
        const m = root.rotatable;
        if (!m)
            return;
        root.setTransform(m.name, (((m.transform % 4) + step) % 4 + 4) % 4);
    }

    // Touch does NOT follow the output transform on its own — an earlier
    // comment here claimed it did, and it was wrong. Hyprland 0.56 maps
    // normalized touch coords linearly onto the bound output's logical box
    // (src/managers/input/Touch.cpp); `input:touchdevice:output` picks WHICH
    // box, never rotates. The only rotation hook is the libinput calibration
    // matrix from input:touchdevice:transform / input:tablet:transform, so
    // setTransform() writes those alongside wlr-randr via `hyprctl -r eval`
    // (a runtime hl.config write trips REFRESH_INPUT_DEVICES, re-applying the
    // matrices live — verified in the 0.56.2 source; plain `hyprctl keyword`
    // is refused under the Lua parser). That covers taps (the
    // qshell-touch-screen clone is a touch device) and the stylus. The
    // 3/4-finger gesture pads are POINTER devices with no calibration path —
    // bin/touch-gestures counter-rotates those itself by watching wl_output.
    function resetRotation(): void {
        const m = root.rotatable;
        if (m)
            root.setTransform(m.name, 0);
    }

    function toggleEdp(): void {
        Quickshell.execDetached([`${root.binDir}/disp`, "toggle"]);
        settle.restart();
    }

    // Hyprland applies these asynchronously; one delayed re-read beats a fast
    // poll that mostly reports the state we already had.
    Timer {
        id: settle

        interval: 900
        repeat: true
        triggeredOnStart: false
        property int ticks: 0

        onRunningChanged: {
            if (running)
                ticks = 0;
        }
        onTriggered: {
            root.refresh();
            if (++ticks >= 3)
                stop();
        }
    }

    // Only while the page is open: this shells out, and nothing else in the
    // shell needs a live monitor list *continuously*.
    Timer {
        running: root.polling
        interval: 3000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // …but the list can no longer be empty until someone opens the page: the
    // tablet's rotate button reads the current transform out of it to work out
    // which quarter turn is next, and a bar button that does nothing until you
    // have visited a settings page is a broken bar button. One read at startup
    // plus one per compositor-level change keeps it current for free.
    Component.onCompleted: root.refresh()

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (["monitoradded", "monitorremoved", "configreloaded"].includes(event.name))
                root.refresh();
        }
    }

    // A transform change emits NO Hyprland event, so a rotation performed
    // outside qshell (bare wlr-randr, a script) left the cache stale: the
    // rotate button's first tap computed from the old transform and no-op'd.
    // A quarter-turn does change the logical geometry, which the Wayland-side
    // screen objects report — watch that. Residual: 180°/flipped transforms
    // change no geometry and stay invisible; settle self-heals those after
    // one tap.
    Instantiator {
        model: Quickshell.screens

        Connections {
            required property var modelData

            target: modelData

            function onWidthChanged(): void {
                root.refresh();
            }

            function onHeightChanged(): void {
                root.refresh();
            }
        }
    }

    // `qs -c qshell ipc call display rotate` — the tablet's rotation keybind.
    // Worth having as a key as well as a bar button: the bar button is a 26px
    // target that has just moved to a different edge of a screen you are
    // holding sideways, and if a rotation goes wrong that is the control you
    // most need to hit.
    IpcHandler {
        target: "display"

        function rotate(): string {
            root.rotate(1);
            return root.rotatable?.name ?? "no output";
        }

        function reset(): string {
            root.resetRotation();
            return root.rotatable?.name ?? "no output";
        }

        function transform(t: string): string {
            const n = parseInt(t, 10);
            const m = root.rotatable;
            if (!m || isNaN(n) || n < 0 || n > 7)
                return "usage: transform 0-7";
            root.setTransform(m.name, n);
            return `${m.name} → ${root.transformNames[n]}`;
        }

        function layout(): string {
            root.applyLayout();
            return "reload";
        }
    }

    Process {
        id: lister

        // `monitors all` includes outputs that exist but are disabled — the
        // plain form hides exactly the ones this page is for. Plain argv:
        // there is nothing here for a shell to expand.
        command: ["hyprctl", "-j", "monitors", "all"]

        stdout: StdioCollector {
            onStreamFinished: {
                let list = [];
                try {
                    list = JSON.parse(text);
                } catch (e) {
                    return;
                }
                root.monitors = list.map(m => ({
                            name: m.name ?? "",
                            description: m.description ?? "",
                            width: m.width ?? 0,
                            height: m.height ?? 0,
                            refresh: Math.round(m.refreshRate ?? 0),
                            scale: m.scale ?? 1,
                            x: m.x ?? 0,
                            y: m.y ?? 0,
                            transform: m.transform ?? 0,
                            focused: m.focused ?? false,
                            disabled: m.disabled ?? false
                        }));
            }
        }
    }
}
