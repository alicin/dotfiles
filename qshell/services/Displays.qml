pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Monitors, for the Control Center's Display page. The layout presets and the
// eDP toggle have been keybind-only (Super+Ctrl+M/E/L, and a bare
// toggle-edp.sh) — invisible, unlabelled, and one of them has a known way to
// leave you with a black laptop panel and no obvious way back.
//
// Reads hyprctl rather than Quickshell.screens because it needs what the
// compositor knows and the Wayland client doesn't: which outputs exist but are
// currently *disabled*, which is exactly the set the eDP toggle moves things
// between.
Singleton {
    id: root

    // [{ name, description, width, height, refresh, scale, x, y, focused, disabled }]
    property var monitors: []
    property bool polling: false

    readonly property var active: root.monitors.filter(m => !m.disabled)

    readonly property string summary: {
        const n = root.active.length;
        if (n === 0)
            return "…";
        if (n === 1)
            return root.active[0].name;
        return `${n} displays`;
    }

    readonly property string binDir: `${Quickshell.env("HOME")}/labs/dotfiles/bin`

    function refresh(): void {
        lister.running = true;
    }

    // The three layouts the Super+Ctrl binds have always applied, by their own
    // names, so the page and the keybinds can't drift apart.
    function applyLayout(which: string): void {
        Quickshell.execDetached(["sh", "-c", `'${root.binDir}/hypr-monitor-manager.sh' "$1"`, "qshell-displays", which]);
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
    function setEnabled(m: var, on: bool): void {
        if (!on && root.active.length <= 1)
            return;
        if (on)
            Quickshell.execDetached(["hyprctl", "reload"]);
        else
            Quickshell.execDetached(["hyprctl", "keyword", "monitor", `${m.name},disable`]);
        settle.restart();
    }

    function toggleEdp(): void {
        Quickshell.execDetached(["sh", "-c", `'${root.binDir}/toggle-edp.sh'`]);
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
    // shell needs a live monitor list.
    Timer {
        running: root.polling
        interval: 3000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: lister

        // `monitors all` includes outputs that exist but are disabled — the
        // plain form hides exactly the ones this page is for.
        command: ["sh", "-c", "hyprctl -j monitors all"]

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
                            focused: m.focused ?? false,
                            disabled: m.disabled ?? false
                        }));
            }
        }
    }
}
