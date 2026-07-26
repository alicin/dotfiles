pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// ROG platform bits via asusctl / supergfxctl: fan profile, battery charge
// limit, and dGPU mode.
//
// Distinct from power-profiles-daemon (which the battery menu already shows) —
// that sets the CPU governor, this sets the ASUS platform profile and fan
// curve. Both exist and they are not the same knob.
Singleton {
    id: root

    // ── Fan / platform profile ──
    property var profiles: []
    property string profile: ""

    // ── Battery charge limit ──
    property int chargeLimit: 100

    // ── dGPU mode ──
    property var gpuModes: []
    property string gpuMode: ""
    // supergfxctl reports what the user must do for a pending mode to apply;
    // "No action required" when there's nothing outstanding.
    property string gpuPending: ""

    property bool available: false

    // Only polled while a menu that shows this is open.
    property bool polling: false

    function refresh(): void {
        reader.running = false;
        reader.running = true;
    }

    function setProfile(p: string): void {
        root.profile = p;
        Quickshell.execDetached(["asusctl", "profile", "set", p]);
        settle.restart();
    }

    function setChargeLimit(pct: int): void {
        root.chargeLimit = pct;
        Quickshell.execDetached(["asusctl", "battery", "limit", `${pct}`]);
        settle.restart();
    }

    // Mode changes never take effect immediately — supergfxd wants a logout or
    // a reboot depending on the transition, which is what gpuPending reports.
    function setGpuMode(m: string): void {
        Quickshell.execDetached(["sh", "-c", `supergfxctl -m ${m}`]);
        settle.restart();
    }

    Timer {
        id: settle

        interval: 1200
        repeat: true
        triggeredOnStart: false
        property int ticks: 0
        onTriggered: {
            ticks++;
            root.refresh();
            if (ticks >= 4) {
                stop();
                ticks = 0;
            }
        }
    }

    Timer {
        running: root.polling
        interval: 3000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: reader

        running: true
        // Tagged lines rather than positional parsing — asusctl's phrasing
        // ("Active profile: Performance") is prose and shifts between releases.
        command: ["sh", "-c", `
            echo "PROFILES $(asusctl profile list 2>/dev/null | tr '\\n' ' ')"
            # 'profile get' prints four lines — the active one plus the separate
            # AC and battery profiles. Only the first is what's in effect.
            echo "PROFILE $(asusctl profile get 2>/dev/null | sed -n 's/^Active profile: *//p' | head -1)"
            echo "LIMIT $(asusctl battery info 2>/dev/null | grep -oE '[0-9]+' | head -1)"
            # Strip only the brackets and quotes, *then* turn commas into
            # separators — deleting the commas first glues the modes together.
            echo "GPUMODES $(supergfxctl -s 2>/dev/null | tr -d '[]"' | tr ',' ' ')"
            echo "GPUMODE $(supergfxctl -g 2>/dev/null)"
            echo "GPUPENDING $(supergfxctl -p 2>/dev/null)"
        `]

        stdout: StdioCollector {
            onStreamFinished: {
                let sawAny = false;
                for (const line of text.split("\n")) {
                    const sp = line.indexOf(" ");
                    if (sp < 1)
                        continue;
                    const key = line.slice(0, sp);
                    const val = line.slice(sp + 1).trim();
                    if (!val)
                        continue;
                    sawAny = true;
                    switch (key) {
                    case "PROFILES":
                        root.profiles = val.split(/\s+/).filter(s => s);
                        break;
                    case "PROFILE":
                        root.profile = val;
                        break;
                    case "LIMIT":
                        root.chargeLimit = parseInt(val, 10) || 100;
                        break;
                    case "GPUMODES":
                        // "[Integrated, Hybrid, Vfio, AsusMuxDgpu]" once the
                        // brackets and commas are stripped by the shell above.
                        root.gpuModes = val.split(/\s+/).filter(s => s);
                        break;
                    case "GPUMODE":
                        root.gpuMode = val;
                        break;
                    case "GPUPENDING":
                        root.gpuPending = /no action/i.test(val) ? "" : val;
                        break;
                    }
                }
                root.available = sawAny && root.profiles.length > 0;
            }
        }
    }

    // Surface the logout/reboot requirement as a real notification — the menu
    // may well be closed by the time supergfxd decides.
    onGpuPendingChanged: {
        if (!gpuPending)
            return;
        Quickshell.execDetached(["notify-send", "-a", "qshell", "-i", "video-display", "-u", "critical", "GPU mode change pending", gpuPending]);
    }
}
