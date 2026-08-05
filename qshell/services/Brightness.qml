pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Display and keyboard backlight via brightnessctl.
//
// "The display" here means the one the user is looking at, which stopped being
// a rhetorical question once an external monitor could be plugged in: the
// slider, the OSD and the Fn keys all used to move the laptop panel no matter
// which screen the pointer and the focus were on, silently and with no way to
// reach the external at all. So there is now a routing step — see `target` —
// and the actual write goes either to brightnessctl (the built-in panel) or to
// Ddc.qml (an external over DDC/CI). The logical 0..1 `display` property means
// the same thing on both paths, so nothing that reads or sets it had to learn
// the difference.
//
// `brightnessctl -m -d <dev> info` prints "name,class,current,percent,max",
// which is the whole reason for using it over raw sysfs — the max differs per
// device (512 for the panel, 3 for the ROG keyboard) and has to be read, not
// assumed.
//
// The kernel gives no change notification we can watch, so the *display* media
// keys call stepDisplay over IPC (see shell.qml) instead of running
// brightnessctl behind our back: that way the OSD reacts on the keypress rather
// than whenever a poll next happens to run.
//
// The keyboard backlight can't work that way, and can't be intercepted at all.
// Its Fn key produces *no* input event on any device — logged every evdev event
// on all 19 devices across dozens of presses and nothing appears, which matches
// the capability bitmaps (no device declares KEY_KBDILLUMUP). asusd doesn't
// announce it either. The firmware changes the LED and the only trace is in
// sysfs, so the only thing that can work is watching sysfs — see kbdHwPoll.
Singleton {
    id: root

    // The keyboard backlight moved, and not because we moved it.
    signal kbdChangedExternally

    readonly property string displayDev: "intel_backlight"
    readonly property string kbdDev: "asus::kbd_backlight"

    // The panel is driven over the eDP HDR backlight interface
    // (i915.enable_dpcd_backlight=3), whose raw register spans the full HDR
    // luminance range — in ordinary SDR desktop use nothing gets any brighter
    // past the top fifth of it. So everything in the shell works on a *logical*
    // 0-1 mapped onto the panel's useful range, and 100% is its real maximum
    // rather than four-fifths of the way up with dead travel above.
    // Keep in sync with MAX_PCT in scripts/rog-backlight-control.sh.
    readonly property int usefulPct: 80

    // Logical 0..1 (see above), not the raw register fraction, and specifically
    // the built-in panel's — `display` below is whichever screen is being
    // driven right now.
    property real panel: 0

    // Which screen the brightness controls mean: the focused one. Not the one
    // under the pointer (you adjust brightness while typing, hands off the
    // trackpad) and not "all of them" (an external and a laptop panel have
    // nothing like the same response curve, so one gesture moving both leaves
    // them mismatched with no way to correct just one).
    readonly property string target: Hyprland.focusedMonitor?.name ?? ""

    // The DDC row for the focused screen, or null if it is the built-in panel —
    // which is also what it is when ddcutil found nothing, when no external is
    // plugged in, and when the external refused to answer. Every one of those
    // collapses to "use brightnessctl", which is the pre-existing behaviour.
    //
    // Written as an inline lookup over Ddc.displays rather than a call to
    // Ddc.forMonitor() so the binding's dependency on that list is impossible
    // to misread — it has to re-evaluate on hotplug and on every DDC read.
    readonly property var ddcTarget: {
        const n = root.target;
        if (!n)
            return null;
        return Ddc.displays.find(d => d.name === n) ?? null;
    }

    readonly property bool usingDdc: root.ddcTarget !== null

    // For the OSD and the Control Center to name what they are moving, the way
    // the volume OSD names the sink. Empty when it is the built-in panel: with
    // one screen there is nothing to disambiguate and a label would be noise.
    readonly property string targetLabel: root.usingDdc ? root.target : ""

    // Logical 0..1 on whichever screen `target` picked out.
    readonly property real display: root.ddcTarget ? root.ddcTarget.level : root.panel

    // 0..kbdMax, integer steps
    property int kbd: 0
    property int kbdMax: 3

    // Last level the *firmware* reported, -1 before the first read. Separate
    // from `kbd` because kbd also moves for software writes.
    property int kbdHw: -1

    property bool kbdAvailable: true

    // Polling is opt-in: only the Control Center cares, and it's only on
    // screen for a few seconds at a time. Anything *else* that moves these
    // (hypridle dimming, asusctl) is picked up by that poll, or by the settle
    // read after our own writes.
    property bool polling: false

    // The DDC side is emphatically *not* polled with it: a getvcp is a DDC
    // round trip on the i2c bus, not a 30µs sysfs read, and doing one every
    // 1.5s would keep the monitor's scaler busy for as long as the panel is
    // open. One read when the panel opens is enough to catch the only thing
    // that moves an external behind our back — its own bezel buttons.
    onPollingChanged: {
        if (root.polling)
            Ddc.refresh();
    }

    // Known before the first keypress, so stepping doesn't have to guess.
    Component.onCompleted: root.refresh()

    function refresh(): void {
        reader.running = false;
        reader.running = true;
    }

    // Never 0: hypridle's dim listener parks the panel at 10, and letting the
    // slider reach 0 leaves a black screen with no obvious way back.
    function setDisplay(v: real): void {
        const logical = Math.max(0.01, Math.min(1, v));
        // The DDC path owns its own floor, debounce and settle read, and
        // usefulPct does not apply to it — an external's 0..max really is its
        // full useful range, where the eDP HDR register's is not.
        if (root.usingDdc) {
            Ddc.setLevel(root.target, logical);
            return;
        }
        const phys = Math.max(1, Math.round(logical * root.usefulPct));
        root.panel = logical;
        Quickshell.execDetached(["brightnessctl", "-d", root.displayDev, "set", `${phys}%`]);
        settle.restart();
    }

    // 10 logical points a press — the same step the standalone script used, so
    // the keys feel identical whether or not the shell is running.
    function stepDisplay(dir: int): void {
        const cur = Math.round(root.display * 100);
        root.setDisplay(Math.max(1, Math.min(100, cur + dir * 10)) / 100);
    }

    function setKbd(level: int): void {
        const next = Math.max(0, Math.min(root.kbdMax, level));
        root.kbd = next;
        Quickshell.execDetached(["brightnessctl", "-d", root.kbdDev, "set", `${next}`]);
        settle.restart();
    }

    function stepKbd(dir: int): void {
        root.setKbd(root.kbd + dir);
    }

    // 1 → 2 → 3 → 0 → 1 … (the Control Center's tap-to-cycle row)
    function cycleKbd(): void {
        root.setKbd(root.kbd >= root.kbdMax ? 0 : root.kbd + 1);
    }

    Timer {
        running: root.polling
        interval: 1500
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // One read after a burst of keypresses settles, so the optimistic values
    // above can't drift from what the hardware actually took.
    Timer {
        id: settle

        interval: 400
        onTriggered: root.refresh()
    }

    // `brightness_hw_changed`, not `brightness`. The LED core writes it only for
    // *hardware*-initiated changes, so it is precisely "the user pressed the
    // key" and nothing else: hypridle blanking the light on idle and our own
    // writes below are software, never appear in it, and need no filtering.
    //
    // It's also 0.03ms to read against 1.9ms for `brightness`, which goes out
    // over WMI to the EC — cheap enough to poll at 120ms and so catch every
    // step of a key repeat (measured ~170ms apart) instead of just the last.
    //
    // Polled rather than poll()ed: the attribute does support sysfs_notify, but
    // reaching POLLPRI from QML would mean a helper process babysitting a file
    // descriptor, and at 0.03% of a core that buys nothing.
    FileView {
        id: kbdHwFile

        path: `/sys/class/leds/${root.kbdDev}/brightness_hw_changed`
        blockLoading: true
        blockAllReads: true
        printErrors: false // -ENODATA until the key has been pressed once
    }

    Timer {
        id: kbdHwPoll

        running: true
        interval: 120
        repeat: true
        onTriggered: {
            kbdHwFile.reload();
            const level = parseInt(kbdHwFile.text(), 10);
            if (isNaN(level) || level === root.kbdHw)
                return;
            // The attribute persists across shell restarts and across software
            // writes, so the value found on the first read is history — it may
            // not even be the current level. Record it, but don't let it
            // overwrite what the reader below saw, and don't announce it.
            const known = root.kbdHw >= 0;
            root.kbdHw = level;
            if (!known)
                return;
            root.kbd = level;
            root.kbdAvailable = true;
            root.kbdChangedExternally();
        }
    }

    Process {
        id: reader

        command: ["sh", "-c", `brightnessctl -m -d ${root.displayDev} info; brightnessctl -m -d ${root.kbdDev} info 2>/dev/null`]

        stdout: StdioCollector {
            onStreamFinished: {
                let sawKbd = false;
                for (const line of text.split("\n")) {
                    const f = line.split(",");
                    if (f.length < 5)
                        continue;
                    const cur = parseInt(f[2], 10);
                    const max = parseInt(f[4], 10);
                    if (!(max > 0))
                        continue;
                    if (f[0] === root.displayDev) {
                        // Raw register fraction → logical.
                        root.panel = Math.max(0, Math.min(1, cur / max / (root.usefulPct / 100)));
                    } else if (f[0] === root.kbdDev) {
                        root.kbd = cur;
                        root.kbdMax = max;
                        sawKbd = true;
                    }
                }
                root.kbdAvailable = sawKbd;
            }
        }
    }
}
