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

    // BackendState verbatim ("Running", "Stopped", "NeedsLogin",
    // "NeedsMachineAuth", "Starting"), or "Unavailable" when the CLI/daemon
    // gives no JSON. The switch used to collapse all of these into "off",
    // which made NeedsLogin and a dismissed pkexec prompt indistinguishable
    // from a clean stop.
    property string state: ""

    // Set when a toggle's ~30s settle window expires with no state change —
    // the only failure signal execDetached leaves us.
    property string lastError: ""

    // What the wifi menu prints under the row; "" when there's nothing to say
    // (Running and Stopped are the two *expected* states).
    readonly property string stateLabel: {
        switch (state) {
        case "NeedsLogin":
            return "Needs login — run: tailscale up";
        case "NeedsMachineAuth":
            return "Awaiting device approval";
        case "Starting":
            return "Starting…";
        case "Unavailable":
            return "Daemon unreachable";
        default:
            return "";
        }
    }

    property int settleTicks: 0

    function refresh(): void {
        statusProc.running = true;
    }

    function toggle(): void {
        busy = true;
        lastError = "";
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
                // The switch was flipped and nothing happened — before this,
                // that outcome was rendered identically to success. Only when
                // no stateLabel already explains the stall (NeedsLogin etc.
                // would make "no response" a wrong diagnosis).
                if (root.stateLabel === "")
                    root.lastError = "No response — was the auth prompt dismissed?";
            }
        }
    }

    Process {
        id: statusProc

        command: ["tailscale", "status", "--json", "--peers=false"]

        stdout: StdioCollector {
            onStreamFinished: {
                const was = root.up;
                let st = "Unavailable";
                try {
                    st = JSON.parse(text).BackendState ?? "Unavailable";
                } catch (e) {}
                root.state = st;
                root.up = st === "Running";
                if (root.up !== was) {
                    settleTimer.stop();
                    root.busy = false;
                    root.lastError = "";
                }
            }
        }
    }
}
