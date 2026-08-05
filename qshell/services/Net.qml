pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Thin view over Quickshell.Networking: the wifi device, its active network,
// and whether any wired link is up. Named `Net` (not `Network`) because
// Quickshell.Networking exports a `Network` type that would shadow this
// singleton in any file importing both.
Singleton {
    id: root

    readonly property var wifi: (Networking.devices?.values ?? []).find(d => d instanceof WifiDevice) ?? null
    readonly property var activeNetwork: wifi?.networks?.values.find(n => n.connected) ?? null

    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool connected: activeNetwork !== null
    readonly property string ssid: activeNetwork?.name ?? ""

    // Only a saved network has anything to forget — an open one you happen to
    // be sitting on has no stored profile to delete.
    readonly property bool activeKnown: activeNetwork?.known ?? false

    // Device-level, so it covers any network mid-connect — per-network
    // stateChanging can't be watched reactively through a list filter.
    readonly property bool connecting: wifi?.state === ConnectionState.Connecting

    // NetworkDevice.address is the MAC; the useful "where am I" is the v4
    // lease, which the backend doesn't expose — read it off the link instead.
    property string ipv4: ""

    // True from a rescan() until the backend has had time to refill the list —
    // there's no scan-finished signal, so this is a fixed-length "spinner on".
    property bool scanning: false

    // signalStrength may be 0..1 or 0..100 depending on backend; normalize to 0..100.
    readonly property int strength: {
        const s = activeNetwork?.signalStrength ?? 0;
        return Math.round(s <= 1 ? s * 100 : s);
    }

    readonly property var ethernetDevices: (Networking.devices?.values ?? []).filter(d => !(d instanceof WifiDevice) && d.name !== "lo")
    readonly property bool ethernet: ethernetDevices.some(d => d.connected)

    function toggleWifi(): void {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    // NetworkDevice exposes disconnect() but no connect — bringing a downed
    // link back goes through nmcli. (The ethernet rows need both directions;
    // a row that can only kill the link is a footgun.)
    function connectDevice(name: string): void {
        Quickshell.execDetached(["nmcli", "device", "connect", name]);
    }

    // disconnect() lives on the Network object, and the wifi menu's summary
    // card — unlike every row below it — has no delegate to reach one through.
    // Silent when nothing is up, so the caller isn't repeating a null check to
    // ask for the obvious.
    function disconnectWifi(): void {
        activeNetwork?.disconnect();
    }

    // There's no explicit scan method on WifiDevice; cycling the scanner is
    // what forces the backend to re-probe.
    function rescan(): void {
        if (!wifi || !Networking.wifiEnabled)
            return;
        wifi.scannerEnabled = false;
        scanning = true;
        rescanKick.restart();
        scanSettle.restart();
    }

    Timer {
        id: rescanKick

        interval: 120
        onTriggered: {
            if (root.wifi)
                root.wifi.scannerEnabled = true;
        }
    }

    Timer {
        id: scanSettle

        interval: 4000
        onTriggered: root.scanning = false
    }

    // Cancels a rescan in flight *and* the pending 120ms kick — the wifi menu
    // calls this on close. Without stopping the kick, a menu destroyed within
    // 120ms of opening (hover-slide pass-through) let the kick re-enable the
    // scanner afterwards, leaving the radio scanning indefinitely.
    function stopScan(): void {
        rescanKick.stop();
        scanSettle.stop();
        scanning = false;
        if (wifi)
            wifi.scannerEnabled = false;
    }

    function refreshIp(): void {
        if (!wifi?.name) {
            ipv4 = "";
            return;
        }
        ipProc.running = false;
        ipProc.running = true;
    }

    onConnectedChanged: refreshIp()
    onSsidChanged: refreshIp()

    Process {
        id: ipProc

        running: true
        command: ["sh", "-c", `ip -4 -o addr show dev ${root.wifi?.name ?? "lo"} scope global | awk '{print $4}' | cut -d/ -f1 | head -1`]

        stdout: StdioCollector {
            onStreamFinished: root.ipv4 = text.trim()
        }
    }
}
