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
// The kernel gives no change notification we can watch, so the *display* media
// keys call stepDisplay over IPC (see shell.qml) instead of running
// brightnessctl behind our back: that way the OSD reacts on the keypress rather
// than whenever a poll next happens to run.
//
// The keyboard backlight can't work that way. This laptop's Fn key for it never
// reaches the compositor — no input device here even declares KEY_KBDILLUMUP
// (checked the evdev capability bitmaps: the Asus WMI hotkeys device exposes
// volume, mic-mute and display brightness, and nothing for the keyboard light),
// so a hyprland bind on XF86KbdBrightnessUp is dead config and always was.
// asusd handles that key itself, so we listen to *it* instead — see kbdWatcher.
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

    // asusd owns the keyboard-light Fn key on this hardware and republishes the
    // level as xyz.ljones.Aura.Brightness, so its PropertiesChanged is the only
    // event there is for "the user changed the keyboard backlight".
    //
    // Conveniently it is *also* exactly the right filter: asusd only signals for
    // changes that went through asusd, so hypridle blanking the light on idle
    // (a raw brightnessctl write) stays silent, and so do our own writes below.
    //
    // Matched on the interface rather than the object path, which carries the
    // device id (/xyz/ljones/aura/19b6_2_6).
    //
    // stdbuf because gdbus block-buffers when its stdout is a pipe, which would
    // sit on an OSD trigger until the next signal pushed it out. setpriv
    // because this is the shell's only long-lived child: `qs kill` reaps it
    // properly, but a bare SIGTERM to the process leaves it orphaned, and one
    // accumulates per restart.
    Process {
        id: kbdWatcher

        running: true
        command: ["setpriv", "--pdeathsig", "TERM", "--", "stdbuf", "-oL", "gdbus", "monitor", "--system", "--dest", "xyz.ljones.Asusd"]

        stdout: SplitParser {
            onRead: line => {
                const m = line.match(/xyz\.ljones\.Aura'.*'Brightness': <uint32 (\d+)>/);
                if (!m)
                    return;
                root.kbd = parseInt(m[1], 10);
                root.kbdAvailable = true;
                root.kbdChangedExternally();
            }
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
