pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Tailscale state via the CLI. `status` reads fine as the user, but `up`/`down`
// and `set` write prefs and need root unless the user is a registered tailscale
// operator, so the writes try unprivileged first and escalate through pkexec
// only when that's refused (exit 1, "Access denied: prefs write access denied")
// — the session's polkit agent puts up the password dialog.
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

    // Set when a write's ~30s settle window expires with no change — the only
    // failure signal execDetached leaves us.
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

    // The tailnet, off the same status poll:
    // [{ name, ip, os, online, exitOption, exitActive }]. The poll used to run
    // with --peers=false, so the shell could say whether Tailscale was up but
    // nothing at all about what was on it.
    property var peers: []

    // Signature of the published list. The peers are rebuilt from scratch on
    // every poll and ScriptModel diffs by object identity, so handing it a
    // fresh array each time would reset the device list — and whatever row the
    // cursor was over — once per settle tick.
    property string peersKey: ""

    readonly property var exitNodes: peers.filter(p => p.exitOption)
    readonly property var exitNode: peers.find(p => p.exitActive) ?? null
    readonly property string exitNodeName: exitNode?.name ?? ""

    // Both writes share the one settle poll, so the picker needs to know
    // whether the "…" currently on screen is its own.
    readonly property bool exitBusy: busy && pending === "exit"

    // What the in-flight write is waiting to see — "up", "down", "exit", or ""
    // when idle. execDetached hands back no exit status, so re-reading status
    // until it agrees is the only way to tell a finished write from a polkit
    // prompt someone closed.
    property string pending: ""

    // The --exit-node value asked for. "" is a legitimate target (route
    // directly again), which is why it can't double as "nothing pending".
    property string exitWant: ""

    property int settleTicks: 0

    function refresh(): void {
        statusProc.running = true;
    }

    function toggle(): void {
        // One write at a time, the same guard `setExitNode` below has always
        // had. Both share the settle poll, and since a switch renders only its
        // bound `checked` the knob doesn't move while the polkit prompt is
        // open — so a second tap looks like the first one missed and queues a
        // second password dialog behind it. Now that the Control Center tile
        // is a second way in, there are two controls that can do it.
        if (busy)
            return;
        busy = true;
        lastError = "";
        const cmd = up ? "down" : "up";
        pending = cmd;
        Quickshell.execDetached(["sh", "-c", `tailscale ${cmd} || pkexec tailscale ${cmd}`]);
        // The polkit prompt can sit open for a while, so poll for the state
        // change rather than guessing one settle delay.
        settleTicks = 0;
        settleTimer.restart();
    }

    // `target` is a peer's tailnet address, or "" to stop using an exit node.
    function setExitNode(target: string): void {
        // One write at a time: they share the settle poll, and a second
        // escalation would queue a second polkit prompt behind the first.
        if (busy || !up)
            return;
        busy = true;
        lastError = "";
        pending = "exit";
        exitWant = target;
        // The target travels as an argument instead of being spliced into the
        // script — it comes off the tailnet, not out of this file.
        Quickshell.execDetached(["sh", "-c", 'tailscale set --exit-node="$1" || pkexec tailscale set --exit-node="$1"', "qshell-tailscale", target]);
        settleTicks = 0;
        settleTimer.restart();
    }

    // Has the write landed? Clearing the exit node settles on the same
    // comparison as setting one, "none" being an empty address.
    function settled(): bool {
        switch (root.pending) {
        case "up":
            return root.up;
        case "down":
            return !root.up;
        case "exit":
            return (root.exitNode?.ip ?? "") === root.exitWant;
        }
        return false;
    }

    // `peer` is the status blob's Peer object, keyed by node key — or null when
    // the daemon gave us nothing, which reads as an empty tailnet.
    function readPeers(peer: var): void {
        const list = [];
        for (const nodeKey in peer) {
            const p = peer[nodeKey];
            const ips = p.TailscaleIPs ?? [];
            // v4 first: it's what gets pasted into ssh, and --exit-node takes
            // an address as happily as a name.
            const ip = ips.find(a => a.indexOf(":") === -1) ?? ips[0] ?? "";
            list.push({
                // The MagicDNS label, not HostName: a host names itself
                // whatever it likes (one iPad on this tailnet answers to
                // "localhost", a laptop to a name with a curly apostrophe in
                // it), and `tailscale status` prints this one too.
                name: (p.DNSName ?? "").split(".")[0] || p.HostName || ip,
                ip,
                os: p.OS ?? "",
                online: p.Online === true,
                exitOption: p.ExitNodeOption === true,
                exitActive: p.ExitNode === true
            });
        }
        list.sort((a, b) => (b.online - a.online) || a.name.localeCompare(b.name));
        const sig = JSON.stringify(list);
        if (sig !== root.peersKey) {
            root.peersKey = sig;
            root.peers = list;
        }
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
                const wasExit = root.pending === "exit";
                root.pending = "";
                // Something was asked for and nothing happened — before this,
                // that outcome was rendered identically to success. Only when
                // no stateLabel already explains the stall (NeedsLogin etc.
                // would make "no response" a wrong diagnosis).
                if (root.stateLabel === "")
                    root.lastError = wasExit ? "Exit node unchanged — was the auth prompt dismissed?" : "No response — was the auth prompt dismissed?";
            }
        }
    }

    Process {
        id: statusProc

        command: ["tailscale", "status", "--json"]

        stdout: StdioCollector {
            onStreamFinished: {
                const was = root.up;
                let st = "Unavailable";
                let peer = null;
                try {
                    const status = JSON.parse(text);
                    st = status.BackendState ?? "Unavailable";
                    peer = status.Peer ?? null;
                } catch (e) {}
                root.state = st;
                root.up = st === "Running";
                root.readPeers(peer);
                // A state change clears the complaint whatever caused it: the
                // settle window can close on a polkit prompt that is answered
                // a minute later, or on `tailscale up` typed in a terminal,
                // and the menu would otherwise keep insisting nothing happened
                // over a switch that has plainly moved.
                if (root.up !== was)
                    root.lastError = "";
                // Settled against what was *asked for* rather than against `up`
                // changing: an exit-node write leaves BackendState exactly
                // where it found it.
                if (root.pending !== "" && root.settled()) {
                    settleTimer.stop();
                    root.busy = false;
                    root.pending = "";
                    root.lastError = "";
                }
            }
        }
    }
}
