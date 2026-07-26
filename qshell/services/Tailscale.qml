pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Tailscale state via the CLI. `status` reads fine as the user, but `up`/`down`
// write prefs and need root unless the user is a registered tailscale operator,
// so toggle() tries unprivileged first and escalates through pkexec only when
// that's refused (exit 1, "Access denied: prefs write access denied") — the
// session's polkit agent puts up the password dialog.
//
// To never see that dialog, run once:
//     sudo tailscale set --operator=$USER
Singleton {
    id: root

    property bool up: false
    property bool busy: false

    property int settleTicks: 0

    function refresh(): void {
        statusProc.running = true;
    }

    function toggle(): void {
        busy = true;
        const cmd = up ? "down" : "up";
        Quickshell.execDetached(["sh", "-c", `tailscale ${cmd} || pkexec tailscale ${cmd}`]);
        // The polkit prompt can sit open for a while, so poll for the state
        // change rather than guessing one settle delay.
        settleTicks = 0;
        settleTimer.restart();
    }

    Timer {
        id: settleTimer

        interval: 1200
        repeat: true
        onTriggered: {
            root.settleTicks++;
            root.refresh();
            // ~30s: long enough to type a password, short enough not to spin
            // forever if the prompt is dismissed.
            if (root.settleTicks >= 25) {
                stop();
                root.busy = false;
            }
        }
    }

    Process {
        id: statusProc

        command: ["tailscale", "status", "--json", "--peers=false"]

        stdout: StdioCollector {
            onStreamFinished: {
                const was = root.up;
                try {
                    root.up = JSON.parse(text).BackendState === "Running";
                } catch (e) {
                    root.up = false;
                }
                if (root.up !== was) {
                    settleTimer.stop();
                    root.busy = false;
                }
            }
        }
    }
}
