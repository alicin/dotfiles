pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Is this thing a tablet right now?
//
// Two hardware facts answer it, and this machine (k3v1n, a detachable
// convertible) reports both:
//
//   • the keyboard is a USB device on the magnetic dock, so detaching it
//     removes it from /proc/bus/input/devices outright
//   • gpio-keys declares SW_TABLET_MODE, which the hinge/dock drives
//
// Either one alone is enough — you can fold a keyboard back without unplugging
// it, and you can unplug one without folding anything — so the resolved answer
// is their OR. Both arrive from bin/tablet-sensors, which is where the evdev
// and udev plumbing lives; see the header there for why it is a helper process
// rather than a poll loop in here.
//
// The single consumer that matters is Settings.touchActive: everything visual
// (Appearance.scale, Appearance.touchTarget, the bar's height, the OSK, the
// edge swipes) reads that one flag, so switching modes is one assignment and
// not a broadcast.
Singleton {
    id: root

    // Raw hardware state, straight from the helper. Both default to the
    // *desktop* answer, so the shell never flashes touch mode during the
    // fraction of a second before the first line arrives.
    property bool keyboardAttached: true
    property bool tabletSwitch: false

    // "normal" | "bottom-up" | "left-up" | "right-up", from iio-sensor-proxy.
    // Permanently "normal" on this hardware — the AMD sensor hub exposes an
    // ambient light sensor and no accelerometer at all (todo-tablet.md has the
    // report-descriptor dump). Wired up anyway so autorotate is a hardware
    // question rather than a software one.
    property string orientation: "normal"

    // Whether there is an accelerometer to autorotate *from*. Reported by the
    // helper rather than assumed, so the Control Center can say why rotation is
    // manual here without this machine's answer being hardcoded into a label —
    // the same shell runs on two other hosts and will run on whatever comes
    // next.
    property bool hasAccelerometer: false

    // Whether the helper is alive and has told us anything. `auto` falls back
    // to desktop while this is false, which is the safe direction: a shell that
    // wrongly thinks it is a tablet grows a keyboard over your windows, and a
    // shell that wrongly thinks it is a laptop is merely the shell you had
    // before any of this existed.
    property bool ready: false

    // THE DEVICE-TYPE GATE. This shell runs on three machines and only one of
    // them has a touchscreen; auto must never flip a laptop into touch mode
    // off the keyboard heuristic alone (an internal keyboard hiding behind
    // tablet-sensors' phantom filter, or a bogus SW_TABLET_MODE from a WMI
    // driver, would otherwise do exactly that). Defaults false — the safe
    // direction, same as `ready`.
    property bool hasTouchscreen: false

    readonly property bool tablet: {
        if (Settings.tabletMode === "tablet")
            return true;    // explicit force stays honored, touchscreen or not
        if (Settings.tabletMode === "desktop")
            return false;
        return root.ready && root.hasTouchscreen && (!root.keyboardAttached || root.tabletSwitch);
    }

    // ── Autorotate ───────────────────────────────────────────────────────────
    // iio-sensor-proxy names the edge of the device that is pointing up; the
    // display has to turn the other way to compensate. Same mapping mutter
    // uses, so a panel that rotates here rotates the way GNOME would have
    // rotated it.
    //
    // This will not fire on k3v1n. `orientation` is fed by monitor-sensor, and
    // there is no accelerometer behind it (see the property's own comment) — so
    // it is "normal" from the first line to the last. That is the honest state
    // of autorotate on this machine: implemented, gated, and starved of input.
    readonly property var orientationTransforms: ({
            "normal": 0,
            "left-up": 1,
            "bottom-up": 2,
            "right-up": 3
        })

    onOrientationChanged: root.applyOrientation()

    function applyOrientation(): void {
        // Locked, docked, or not a tablet right now: the screen stays where it
        // is. Rotating a laptop's panel because the sensor moved while the lid
        // was being adjusted is the behaviour rotation locks exist for.
        if (Settings.rotationLock || !root.tablet)
            return;
        const t = root.orientationTransforms[root.orientation];
        const m = Displays.rotatable;
        if (t === undefined || !m || m.transform % 4 === t)
            return;
        Displays.setTransform(m.name, t);
    }

    // Cycles the three-state setting from a bar tap. Desktop is not in the
    // cycle on purpose: "auto" already means desktop whenever a keyboard is
    // attached, so the useful toggle is "trust the hardware" ⇄ "I am holding
    // this thing", and a third stop that only differs while undocked would be
    // one press too many to get back.
    function cycleMode(): void {
        Settings.setTabletMode(Settings.tabletMode === "tablet" ? "auto" : "tablet");
    }

    // The one write. Bound rather than assigned in a handler so it also
    // survives the setting being edited in settings.json underneath us.
    Binding {
        target: Settings
        property: "touchActive"
        value: root.tablet
    }

    Process {
        id: sensors

        running: true
        command: [`${Quickshell.env("HOME")}/labs/dotfiles/bin/tablet-sensors`]

        // Restart rather than give up: the helper's own sources (a udevadm it
        // spawns, an evdev node that can go away on a suspend/resume cycle) can
        // all end, and a shell that silently stopped noticing the keyboard is
        // worse than one that costs a process respawn every few seconds in the
        // pathological case. `ready` drops with the process: its facts are
        // stale now, and the OR-resolved tablet answer must fall back to the
        // desktop default until the respawn reports again.
        onExited: {
            root.ready = false;
            restart.start();
        }

        stdout: SplitParser {
            onRead: line => {
                let state;
                try {
                    state = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (typeof state.keyboard === "boolean")
                    root.keyboardAttached = state.keyboard;
                if (typeof state.tabletMode === "boolean")
                    root.tabletSwitch = state.tabletMode;
                if (typeof state.orientation === "string")
                    root.orientation = state.orientation;
                if (typeof state.accelerometer === "boolean")
                    root.hasAccelerometer = state.accelerometer;
                if (typeof state.touchscreen === "boolean")
                    root.hasTouchscreen = state.touchscreen;
                root.ready = true;
            }
        }
    }

    Timer {
        id: restart

        interval: 3000
        onTriggered: sensors.running = true
    }

    // `qs -c qshell ipc call tablet toggle` — a keybind hook, and the thing to
    // reach for when the shell has the mode wrong and the keyboard you would
    // use to fix it is the one that is missing.
    IpcHandler {
        target: "tablet"

        function toggle(): string {
            root.cycleMode();
            return Settings.tabletMode;
        }

        function mode(m: string): string {
            Settings.setTabletMode(m);
            return Settings.tabletMode;
        }

        function status(): string {
            return JSON.stringify({
                mode: Settings.tabletMode,
                tablet: root.tablet,
                hasTouchscreen: root.hasTouchscreen,
                keyboardAttached: root.keyboardAttached,
                tabletSwitch: root.tabletSwitch,
                orientation: root.orientation,
                hasAccelerometer: root.hasAccelerometer,
                ready: root.ready
            });
        }
    }
}
