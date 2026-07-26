pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Display and keyboard backlight via brightnessctl.
//
// `brightnessctl -m -d <dev> info` prints "name,class,current,percent,max",
// which is the whole reason for using it over raw sysfs — the max differs per
// device (512 for the panel, 3 for the ROG keyboard) and has to be read, not
// assumed.
//
// The kernel gives no change notification we can watch, so the media keys call
// stepDisplay/stepKbd over IPC (see shell.qml) instead of running brightnessctl
// behind our back: that way the OSD reacts on the keypress rather than whenever
// a poll next happens to run.
Singleton {
    id: root

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

    // Logical 0..1 (see above), not the raw register fraction.
    property real display: 0
    // 0..kbdMax, integer steps
    property int kbd: 0
    property int kbdMax: 3

    property bool kbdAvailable: true

    // Polling is opt-in: only the Control Center cares, and it's only on
    // screen for a few seconds at a time. Anything *else* that moves these
    // (hypridle dimming, asusctl) is picked up by that poll, or by the settle
    // read after our own writes.
    property bool polling: false

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
        const phys = Math.max(1, Math.round(logical * root.usefulPct));
        root.display = logical;
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
                        root.display = Math.max(0, Math.min(1, cur / max / (root.usefulPct / 100)));
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
