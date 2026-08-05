pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Brightness on *external* monitors, over DDC/CI (ddcutil).
//
// The laptop panel has a kernel backlight device and brightnessctl writes it in
// under a millisecond; an external monitor has neither. The only channel is
// DDC/CI — a handful of bytes over the I2C lines that run alongside the video
// pairs in the DP/HDMI cable, addressed to the monitor's own scaler. That is
// slow (see the debounce below), lossy, and entirely absent on the built-in
// panel, so it lives here rather than being folded into Brightness.qml's
// brightnessctl path. Brightness.qml picks between the two.
//
// Three facts about ddcutil shape everything in this file:
//
//   * `ddcutil detect` is measured in *seconds*, not milliseconds — it walks
//     every /dev/i2c-* bus and does a real DDC exchange on each. It runs once,
//     and again only when the set of connected outputs changes.
//   * a single setvcp is tens to hundreds of milliseconds, so writes have to be
//     coalesced or a slider drag queues dozens of them (see the coalesce timer).
//   * it exits 1 on a failed read but its *batched* output has to be parsed for
//     the literal token "ERR" instead, because the reader below runs several
//     getvcp calls in one shell and only the last exit code would survive.
//
// The bridge between ddcutil and the rest of the shell is the DRM connector.
// ddcutil prints "DRM connector: card1-DP-1"; the kernel's own directory
// (/sys/class/drm) uses the same names; Wayland — and therefore Hyprland and
// Quickshell.screens — uses that name with the "card<N>-" card prefix stripped,
// so card1-DP-1 is Hyprland's DP-1. Verified on this machine: /sys/class/drm
// holds card1-eDP-1, card1-DP-1..3 and card1-HDMI-A-1, and hyprctl calls the
// panel eDP-1. Everything downstream keys on the stripped name, which is what
// Displays.qml, Hyprland.focusedMonitor and Quickshell.screens all speak.
//
// Nothing here has been exercised against a real DDC monitor: this laptop has
// no external attached, and its own panel reports as "Invalid display" —
// ddcutil says so in as many words ("This is a laptop display. Laptop displays
// do not support DDC/CI"). The whole file is therefore written to be inert
// rather than merely harmless when there is nothing to drive: with no non-eDP
// output connected, ddcutil is never even spawned, `displays` stays empty, and
// Brightness.qml routes every request to the panel exactly as it did before.
Singleton {
    id: root

    // Monitors that answered a real brightness read, as
    // [{ name, bus, connector, monitor, level, max }] — `name` being the
    // Hyprland/Wayland output name and `level` a logical 0..1.
    //
    // A display is published only once getvcp has come back with a value, so
    // there is never a row here with a made-up level for a slider to snap to.
    // The cost is a second or two after a hotplug during which brightness still
    // goes to the panel; the alternative — showing 50% and then jumping — is
    // worse, and hotplugging is not a thing you do mid-drag.
    property var displays: []

    // Unlike the eDP path, DDC brightness needs no usefulPct-style remapping:
    // feature 0x10 is defined as the monitor's own 0..max luminance control and
    // the top of it is genuinely the top.
    readonly property bool available: root.displays.length > 0

    // True from the first probe attempt reaching a conclusion, so dump() can
    // tell "no DDC monitor" apart from "haven't looked yet".
    property bool probed: false

    // What detect found before the level read filtered it, for dump() only.
    property var candidates: []

    // Last ddcutil failure, kept for dump(). Not surfaced in the UI: a monitor
    // that ignores DDC is not something the user can act on from here.
    property string lastError: ""

    // Consecutive failed writes per output name. A monitor in standby answers
    // nothing and each attempt costs ddcutil its full retry budget, so after a
    // few strikes we stop trying until the next probe rather than making every
    // Fn press spawn a process that will sit there for seconds.
    property var strikes: ({})

    // Latest requested level per output name, 0..1 — the coalescing buffer.
    property var pending: ({})

    readonly property bool busy: detector.running || reader.running || writer.running

    // eDP is the lid panel, LVDS its pre-DP ancestor, DSI the panel bus on
    // tablet-ish hardware. None of the three speaks DDC/CI, and the eDP one is
    // already driven by brightnessctl — probing them is pure waste, and worse,
    // an i2c write aimed at a panel that does not implement MCCS is exactly the
    // sort of thing that has been known to confuse a display's firmware.
    function isInternal(name: string): bool {
        return /^(eDP|LVDS|DSI)/i.test(name);
    }

    function forMonitor(name: string): var {
        return root.displays.find(d => d.name === name) ?? null;
    }

    // Set logical 0..1 on one output. Optimistic: the row updates now so the
    // slider tracks the finger, and the wire write follows when the drag pauses.
    function setLevel(name: string, level: real): void {
        const d = root.forMonitor(name);
        if (!d)
            return;
        // Floored, not clamped to zero, for the same reason the panel is: a
        // display at 0 is a black display, and on the monitor you are looking
        // at there is then nothing left on screen to turn it back up with.
        const v = Math.max(0.01, Math.min(1, level));
        root.displays = root.displays.map(x => x.name === name ? Object.assign({}, x, {
                    level: v
                }) : x);
        root.pending[name] = v;
        coalesce.restart();
    }

    function stepLevel(name: string, delta: real): void {
        const d = root.forMonitor(name);
        if (d)
            root.setLevel(name, d.level + delta);
    }

    // One read of what the monitors actually hold. Called after a write burst
    // settles, and by the Control Center when it opens — the buttons on the
    // monitor's own bezel move this behind our back and nothing tells us.
    function refresh(): void {
        if (root.candidates.length === 0)
            return;
        // A read has to wait for the wire rather than be dropped: the caller
        // may be the Control Center opening mid-drag, and a dropped read there
        // is a slider that never catches up with what the monitor took.
        if (root.busy) {
            settle.restart();
            return;
        }
        reader.command = ["sh", "-c", 'for b in "$@"; do echo "BUS $b"; ddcutil --bus "$b" --brief getvcp 10 2>/dev/null; done', "qshell-ddc", ...root.candidates.map(c => `${c.bus}`)];
        reader.running = true;
    }

    // Re-probe from scratch. Public so an IPC verb or the Display page can
    // force it; everything else goes through the hotplug settle below.
    function probe(): void {
        // The cheap exit, and the one this machine takes every time: if no
        // connected output could possibly speak DDC, ddcutil is not run at all.
        // Being merely fast here would still mean seconds of i2c traffic on
        // every shell reload for a laptop that has one panel.
        const external = Quickshell.screens.filter(s => !root.isInternal(s.name));
        if (external.length === 0) {
            root.candidates = [];
            root.displays = [];
            root.probed = true;
            return;
        }
        if (detector.running)
            return;
        detector.running = true;
    }

    function dump(): string {
        if (!root.probed)
            return `ddc: probing… outputs=${Quickshell.screens.map(s => s.name).join(",")}`;
        const outputs = Quickshell.screens.map(s => `${s.name}${root.isInternal(s.name) ? " (internal)" : ""}`).join(", ");
        const rows = root.displays.map(d => `  ${d.name} bus=${d.bus} connector=${d.connector} monitor="${d.monitor}" level=${Math.round(d.level * 100)}% max=${d.max} strikes=${root.strikes[d.name] ?? 0}`);
        const unusable = root.candidates.filter(c => !root.forMonitor(c.name)).map(c => `  ${c.name} bus=${c.bus} — detected but no brightness read`);
        return [`ddc: available=${root.available} busy=${root.busy} outputs=[${outputs}]`, ...rows, ...unusable, `  pending=${JSON.stringify(root.pending)} lastError="${root.lastError}"`].join("\n");
    }

    Component.onCompleted: root.probe()

    // The set of connected outputs, as a string so a plain change handler can
    // watch it. Quickshell.screens is the Wayland output registry and updates
    // itself on hotplug — no polling, and unlike Displays.monitors it is live
    // even when the Control Center's Display page has never been opened. (It
    // cannot see *disabled* outputs, which is why Displays.qml shells out to
    // hyprctl; a disabled output is one nobody can be adjusting the brightness
    // of, so that distinction does not matter here.)
    readonly property string outputKey: Quickshell.screens.map(s => s.name).sort().join(",")

    onOutputKeyChanged: hotplug.restart()

    // 2s after the output set stops changing. A single plug-in produces a burst
    // of registry changes, and more importantly the DRM connector appearing and
    // the monitor's i2c actually answering are not the same instant — a monitor
    // still bringing up its link ACKs nothing, and a detect fired on the first
    // change reports it as absent for as long as nobody replugs it.
    Timer {
        id: hotplug

        interval: 2000
        onTriggered: root.probe()
    }

    // 150ms of quiet before the value goes out on the wire. A drag emits a new
    // value every frame — 8ms at 120Hz — against a setvcp that costs tens to
    // hundreds of milliseconds, so writing every one of them would build a
    // queue the monitor spends the rest of the minute draining. 150ms is the
    // same order as one write, which keeps the queue at most one deep, and
    // stays under the quarter-second at which the light stops feeling attached
    // to the gesture that caused it.
    Timer {
        id: coalesce

        interval: 150
        onTriggered: root.flush()
    }

    // One read after the burst, to pick up whatever the monitor actually took —
    // they clamp, round to their own step size, and quietly ignore values while
    // in a menu. 1200ms rather than the panel path's 400ms because a DDC write
    // is three orders of magnitude slower than a brightnessctl one, and a read
    // that lands while the queue is still draining just gets deferred anyway.
    Timer {
        id: settle

        interval: 1200
        onTriggered: root.refresh()
    }

    // The level read can't be fired from the parse above: stdout closes — and
    // so onStreamFinished runs — while detect is still technically running, and
    // refresh() rightly refuses to put a read on a bus ddcutil still owns.
    // 250ms is simply "after that process is gone", not a tuned number.
    Timer {
        id: readSoon

        interval: 250
        onTriggered: root.refresh()
    }

    // Writes one queued value, if the wire is free. Never called directly from
    // setLevel: a write already in flight owns the bus, and the exit handler
    // below picks up whatever arrived meanwhile.
    function flush(): void {
        // Come back rather than give up: the queued value is the one the user
        // just chose, and dropping it because a settle read happened to be on
        // the bus would leave the monitor one step behind the slider forever.
        if (root.busy) {
            coalesce.restart();
            return;
        }
        const name = Object.keys(root.pending)[0];
        if (name === undefined)
            return;
        const level = root.pending[name];
        delete root.pending[name];
        const d = root.forMonitor(name);
        // Unplugged since the gesture, or struck out — either way there is
        // nothing to write, but any other queued display still deserves a turn.
        if (!d || (root.strikes[name] ?? 0) >= 3) {
            if (Object.keys(root.pending).length > 0)
                coalesce.restart();
            return;
        }
        writer.target = name;
        // --noverify drops ddcutil's read-back after the write, which is a
        // second full DDC round trip for a value we are about to re-read once
        // at settle anyway — it roughly halves the cost of a drag.
        writer.command = ["ddcutil", "--bus", `${d.bus}`, "--noverify", "setvcp", "10", `${Math.max(1, Math.round(level * d.max))}`];
        writer.running = true;
    }

    Process {
        id: writer

        property string target: ""

        stderr: StdioCollector {
            id: writerErr
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                root.strikes[writer.target] = 0;
            } else {
                root.strikes[writer.target] = (root.strikes[writer.target] ?? 0) + 1;
                root.lastError = writerErr.text.trim().split("\n").pop() || `setvcp exited ${exitCode}`;
            }
            // Straight on to the next queued value with no further wait — the
            // debounce has already been served; delaying again here would make
            // a long drag lag behind the finger by a multiple of the interval.
            if (Object.keys(root.pending).length > 0)
                root.flush();
            else
                settle.restart();
        }
    }

    Process {
        id: detector

        // --brief is the parseable form: one unindented header line per display
        // followed by indented fields. The header is "Display <n>" for a usable
        // one and "Invalid display" for anything else — which is precisely how
        // the laptop panel presents, so keying on that header is what keeps eDP
        // out without having to special-case it by name.
        command: ["ddcutil", "detect", "--brief"]

        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                let cur = null;
                for (const line of text.split("\n")) {
                    if (!/^\s/.test(line)) {
                        if (cur)
                            found.push(cur);
                        // Only "Display <n>" is a display we may talk to.
                        cur = /^Display\s+\d+/.test(line) ? {
                            bus: -1,
                            connector: "",
                            monitor: ""
                        } : null;
                        continue;
                    }
                    if (!cur)
                        continue;
                    const m = line.match(/^\s+([^:]+):\s+(.*?)\s*$/);
                    if (!m)
                        continue;
                    const key = m[1].trim();
                    if (key === "I2C bus")
                        cur.bus = parseInt(m[2].replace(/^.*i2c-/, ""), 10);
                    else if (key === "DRM connector")
                        cur.connector = m[2];
                    else if (key === "Monitor")
                        cur.monitor = m[2];
                }
                if (cur)
                    found.push(cur);

                root.candidates = found.map(f => Object.assign({}, f, {
                            name: root.nameFor(f)
                        })).filter(f => f.bus >= 0 && f.name && !root.isInternal(f.name));
                root.strikes = ({});
                if (root.candidates.length === 0) {
                    root.displays = [];
                    root.probed = true;
                    return;
                }
                readSoon.restart();
            }
        }

        stderr: StdioCollector {
            id: detectorErr
        }

        onExited: exitCode => {
            // A non-zero detect still often carries usable displays on stdout
            // (one dead bus among several), so this only records the reason —
            // the parse above decides what exists. Missing i2c-dev, the usual
            // cause of a total failure, lands here and leaves displays empty,
            // which is the same silent no-op as having no external at all.
            if (exitCode !== 0)
                root.lastError = detectorErr.text.trim().split("\n").pop() || `detect exited ${exitCode}`;
            root.probed = true;
        }
    }

    // ddcutil's DRM connector line ("card1-DP-1") minus the card prefix is the
    // Wayland output name ("DP-1"). When ddcutil can't report a connector —
    // older builds, or a bus with no DRM association — fall back to matching
    // the EDID model out of its "Monitor: MFG:MODEL:SERIAL" field against the
    // model Wayland reports for each output. That fallback is why the field is
    // kept at all; it is second choice because two identical monitors are
    // indistinguishable by model and the connector never is.
    function nameFor(f: var): string {
        if (f.connector)
            return f.connector.replace(/^card\d+-/, "");
        const model = (f.monitor ?? "").split(":")[1] ?? "";
        if (!model)
            return "";
        const hit = Quickshell.screens.find(s => !root.isInternal(s.name) && s.model === model);
        return hit?.name ?? "";
    }

    Process {
        id: reader

        stdout: StdioCollector {
            onStreamFinished: {
                // "BUS <n>" markers emitted by the loop in refresh(), each
                // followed by that bus's getvcp output. Batched into one shell
                // because a Process per monitor would race for the same i2c
                // controller; the price is that per-call exit codes are gone,
                // hence the "ERR" check below — ddcutil prints "VCP 10 ERR" on
                // a failed read and a five-field "VCP 10 C <cur> <max>" line on
                // a good one.
                const levels = {};
                let bus = -1;
                for (const line of text.split("\n")) {
                    const b = line.match(/^BUS\s+(\d+)/);
                    if (b) {
                        bus = parseInt(b[1], 10);
                        continue;
                    }
                    const f = line.trim().split(/\s+/);
                    if (f[0] !== "VCP" || f.length < 5 || f[2] === "ERR")
                        continue;
                    const cur = parseInt(f[3], 10);
                    const max = parseInt(f[4], 10);
                    if (bus >= 0 && max > 0)
                        levels[bus] = {
                            level: Math.max(0, Math.min(1, cur / max)),
                            max: max
                        };
                }
                // A monitor that was detected but wouldn't give up feature 0x10
                // is dropped rather than published with a guessed level: with
                // no row here, Brightness.qml routes to the panel, which is at
                // least a control that works.
                root.displays = root.candidates.filter(c => levels[c.bus] !== undefined).map(c => Object.assign({}, c, levels[c.bus]));
                root.probed = true;
            }
        }
    }
}
