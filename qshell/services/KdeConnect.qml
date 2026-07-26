pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// KDE Connect devices over the daemon's DBus API.
//
// Deliberately NOT `kdeconnect-cli --list-devices`: that prints prose
// ("- Pixel 10 Pro XL: <id> on 10.0.0.5 via LAN (paired and reachable)") whose
// shape changes between releases — the middle "on … via …" clause is what
// silently broke the old regex and left the menu showing "No paired devices"
// while the phone was plainly connected. busctl --json=short gives the same
// facts as parseable JSON.
Singleton {
    id: root

    // [{ id, name, type, paired, reachable, battery, charging, signal, network }]
    property var devices: []
    readonly property var reachable: devices.filter(d => d.reachable)

    property string lastRaw: "" // debug: last lister stdout

    function refresh(): void {
        lister.running = false;
        lister.running = true;
    }

    function ring(id: string): void {
        Quickshell.execDetached(["kdeconnect-cli", "--device", id, "--ring"]);
    }

    function ping(id: string): void {
        Quickshell.execDetached(["kdeconnect-cli", "--device", id, "--ping"]);
    }

    // Push the clipboard to the phone — the one "share" that needs no picker.
    function sendClipboard(id: string): void {
        Quickshell.execDetached(["sh", "-c", `kdeconnect-cli --device ${id} --share-text "$(wl-paste -n)"`]);
    }

    function openApp(): void {
        Quickshell.execDetached(["kdeconnect-app"]);
    }

    // GetAll returns {"type":"a{sv}","data":[{ key: {type,data}, … }]} — unwrap
    // to a plain object, tolerating a missing/failed call (absent plugin).
    function props(blob: string): var {
        if (!blob)
            return ({});
        try {
            const inner = JSON.parse(blob).data[0] ?? {};
            const out = {};
            for (const k in inner)
                out[k] = inner[k].data;
            return out;
        } catch (e) {
            return ({});
        }
    }

    Timer {
        running: true
        interval: 30000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: lister

        // One record per device: id \t device props \t battery \t connectivity.
        // Battery/connectivity are per-plugin objects that may not exist; their
        // stderr is dropped and the field comes back empty.
        command: ["sh", "-c", `
            svc=org.kde.kdeconnect
            ids=$(busctl --user call $svc /modules/kdeconnect $svc.daemon devices bb false false 2>/dev/null | tr ' ' '\\n' | sed -n 's/^"\\(.*\\)"$/\\1/p')
            for id in $ids; do
              p=/modules/kdeconnect/devices/$id
              get() { busctl --user --json=short call $svc "$1" org.freedesktop.DBus.Properties GetAll s "$2" 2>/dev/null | tr -d '\\n'; }
              printf '%s\\t%s\\t%s\\t%s\\n' "$id" \\
                "$(get $p $svc.device)" \\
                "$(get $p/battery $svc.device.battery)" \\
                "$(get $p/connectivity_report $svc.device.connectivity_report)"
            done
        `]

        stdout: StdioCollector {
            onStreamFinished: {
                root.lastRaw = text;
                const devs = [];
                for (const line of text.split("\n")) {
                    if (!line.trim())
                        continue;
                    const [id, info, batt, conn] = line.split("\t");
                    if (!id)
                        continue;
                    const d = root.props(info);
                    const b = root.props(batt);
                    const c = root.props(conn);
                    devs.push({
                        id: id,
                        name: d.name ?? id,
                        type: d.type ?? "phone",
                        paired: d.isPaired ?? false,
                        reachable: d.isReachable ?? false,
                        battery: b.charge ?? -1,
                        charging: b.isCharging ?? false,
                        // 0..4 bars, -1 when the plugin isn't reporting.
                        signal: c.cellularNetworkStrength ?? -1,
                        network: c.cellularNetworkType ?? ""
                    });
                }
                root.devices = devs.filter(d => d.paired).sort((a, b) => (b.reachable - a.reachable) || a.name.localeCompare(b.name));
            }
        }
    }
}
