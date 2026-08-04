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

    // The connection currently toggling (drives the row's "…"), and the last
    // one whose toggle failed, with nmcli's first error line. execDetached
    // threw the exit status away, so a missing secret or unreachable endpoint
    // looked exactly like success.
    property string busyFor: ""
    property string failedFor: ""
    property string failedMsg: ""

    function refresh(): void {
        lister.running = true;
    }

    function toggle(conn: var): void {
        // One toggle at a time: the toggler is a single Process, and a second
        // flip mid-flight would clobber its command.
        if (busyFor !== "")
            return;
        busyFor = conn.name;
        failedFor = "";
        failedMsg = "";
        // --wait caps how long a stuck `up` can hold the row busy; nmcli's
        // default is 90s of silence.
        toggler.command = ["nmcli", "--wait", "15", "connection", conn.active ? "down" : "up", conn.name];
        toggler.running = true;
    }

    Process {
        id: toggler

        stderr: StdioCollector {
            id: togErr
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.failedFor = root.busyFor;
                root.failedMsg = (togErr.text.trim().split("\n")[0] || `nmcli exited ${exitCode}`).replace(/^Error: */, "");
            }
            root.busyFor = "";
            root.refresh();
        }
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
