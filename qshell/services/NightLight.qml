pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Blue-light filter, via hyprsunset. There is no gamma tooling anywhere else
// in this config — the machine simply had no night mode.
//
// hyprsunset is a daemon that holds the gamma table for as long as it runs and
// restores it on exit, so "off" is `pkill` rather than a second temperature.
// Its presence is probed rather than assumed: the Control Center tile says so
// instead of offering a switch that does nothing.
Singleton {
    id: root

    readonly property bool enabled: persist.enabled
    readonly property int temperature: persist.temperature

    // -1 until the probe answers, so the tile can stay quiet rather than
    // flashing "not installed" on every shell start.
    property int haveTool: -1
    readonly property bool available: haveTool === 1

    function toggle(): void {
        persist.enabled = !persist.enabled;
        root.apply();
    }

    function setTemperature(t: int): void {
        persist.temperature = t;
        if (persist.enabled)
            root.apply();
    }

    function apply(): void {
        if (!root.available)
            return;
        // Always kill first: a second hyprsunset would fight the first for the
        // gamma table, and which one wins is a race.
        if (root.enabled)
            Quickshell.execDetached(["sh", "-c", `pkill -x hyprsunset; sleep 0.2; hyprsunset -t ${root.temperature} >/dev/null 2>&1 &`]);
        else
            Quickshell.execDetached(["sh", "-c", "pkill -x hyprsunset"]);
    }

    // Probes for the tool *and* for a daemon already holding the gamma table.
    // Restarting a running hyprsunset on every config reload would flash the
    // screen back to daylight and in again, several times an evening while
    // this shell is being worked on.
    Process {
        id: probe

        running: true
        command: ["sh", "-c", `
            command -v hyprsunset >/dev/null && printf yes || printf no
            pgrep -x hyprsunset >/dev/null && printf ' live' || printf ' dead'
        `]

        stdout: StdioCollector {
            onStreamFinished: {
                const [tool, live] = text.trim().split(" ");
                root.haveTool = tool === "yes" ? 1 : 0;
                if (!root.available)
                    return;
                if (root.enabled !== (live === "live"))
                    root.apply();
            }
        }
    }

    PersistentProperties {
        id: persist

        reloadableId: "qshellNightLight"

        property bool enabled: false
        property int temperature: 4000
    }
}
