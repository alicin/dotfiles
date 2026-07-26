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
Singleton {
    id: root

    readonly property string displayDev: "intel_backlight"
    readonly property string kbdDev: "asus::kbd_backlight"

    // 0..1
    property real display: 0
    // 0..kbdMax, integer steps
    property int kbd: 0
    property int kbdMax: 3

    property bool kbdAvailable: true

    // Polling is opt-in: only the Control Center cares, and it's only on
    // screen for a few seconds at a time. The function keys change these
    // behind our back, so while it *is* open we do need to re-read.
    property bool polling: false

    function refresh(): void {
        reader.running = false;
        reader.running = true;
    }

    // Never 0: hypridle's dim listener parks the panel at 10, and letting the
    // slider reach 0 leaves a black screen with no obvious way back.
    function setDisplay(v: real): void {
        const pct = Math.max(1, Math.min(100, Math.round(v * 100)));
        root.display = pct / 100;
        Quickshell.execDetached(["brightnessctl", "-d", root.displayDev, "set", `${pct}%`]);
    }

    // 1 → 2 → 3 → 0 → 1 …
    function cycleKbd(): void {
        const next = root.kbd >= root.kbdMax ? 0 : root.kbd + 1;
        root.kbd = next;
        Quickshell.execDetached(["brightnessctl", "-d", root.kbdDev, "set", `${next}`]);
    }

    Timer {
        running: root.polling
        interval: 1500
        repeat: true
        triggeredOnStart: true
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
                        root.display = cur / max;
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
