pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// VPN/WireGuard connections via nmcli (the Quickshell Networking module
// doesn't expose VPN connections). refresh() is called when the network
// menu opens and shortly after a toggle.
Singleton {
    id: root

    // [{ name, type, active }]
    property var connections: []

    function refresh(): void {
        lister.running = true;
    }

    function toggle(conn: var): void {
        Quickshell.execDetached(["nmcli", "connection", conn.active ? "down" : "up", conn.name]);
        refreshSoon.restart();
    }

    Timer {
        id: refreshSoon

        interval: 1500
        onTriggered: root.refresh()
    }

    Process {
        id: lister

        command: ["nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "connection", "show"]

        stdout: StdioCollector {
            onStreamFinished: {
                const conns = [];
                for (const line of text.split("\n")) {
                    if (!line)
                        continue;
                    // -t escapes ':' inside fields as '\:' — split manually.
                    const parts = [];
                    let cur = "";
                    for (let i = 0; i < line.length; i++) {
                        if (line[i] === "\\" && line[i + 1] === ":") {
                            cur += ":";
                            i++;
                        } else if (line[i] === ":") {
                            parts.push(cur);
                            cur = "";
                        } else {
                            cur += line[i];
                        }
                    }
                    parts.push(cur);
                    if (parts.length < 3)
                        continue;
                    const [name, type, device] = parts;
                    if (type === "vpn" || type === "wireguard")
                        conns.push({
                            name,
                            type,
                            active: device !== ""
                        });
                }
                root.connections = conns;
            }
        }
    }
}
