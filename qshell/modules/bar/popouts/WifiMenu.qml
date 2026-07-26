import QtQuick
import Quickshell
import Quickshell.Networking
import qs.config
import qs.components
import qs.services

// Wi-Fi toggle, current-connection summary, scanned networks (scan runs while
// open, refreshable), plus ethernet devices, Tailscale and VPN connections.
Column {
    id: root

    // Rows past this scroll instead of growing the menu.
    readonly property int maxVisibleRows: 6

    property string pskFor: "" //   ssid with the password row expanded
    property string failedFor: ""

    // The active network gets its own summary card up top, so drop it from the
    // list rather than showing it twice.
    readonly property var networks: {
        const map = new Map();
        for (const n of Net.wifi?.networks.values ?? []) {
            if (!n.name || n.connected)
                continue;
            const cur = map.get(n.name);
            if (!cur || n.signalStrength > cur.signalStrength)
                map.set(n.name, n);
        }
        return [...map.values()].sort((a, b) => (b.known - a.known) || (b.signalStrength - a.signalStrength)).slice(0, 40);
    }

    function strengthPct(n: var): real {
        return n.signalStrength <= 1 ? n.signalStrength * 100 : n.signalStrength;
    }

    width: Appearance.s(330)
    spacing: Appearance.s(2)

    Component.onCompleted: {
        if (Net.wifi)
            Net.wifi.scannerEnabled = true;
        Vpn.refresh();
        Tailscale.refresh();
    }

    Component.onDestruction: {
        if (Net.wifi)
            Net.wifi.scannerEnabled = false;
    }

    Item {
        width: parent.width
        height: Appearance.sizes.menuRowHeight

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: "Wi-Fi"
            color: Theme.surfaceFg
        }

        StyledSwitch {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: Networking.wifiEnabled
            onToggled: checked => Networking.wifiEnabled = checked
        }
    }

    // ── Current connection ──
    Rectangle {
        visible: Networking.wifiEnabled && Net.connected
        width: parent.width
        height: Appearance.s(52)
        radius: Appearance.rounding.normal
        color: Theme.surfaceHoverBg

        FIcon {
            id: curGlyph

            x: Appearance.s(10)
            anchors.verticalCenter: parent.verticalCenter
            icon: "wifi"
            color: Theme.accent
        }

        Column {
            anchors.left: curGlyph.right
            anchors.leftMargin: Appearance.s(10)
            anchors.right: parent.right
            anchors.rightMargin: Appearance.s(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.s(1)

            StyledText {
                width: parent.width
                text: Net.ssid
                color: Theme.surfaceFg
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                text: {
                    const bits = [`${Net.strength}%`];
                    if (Net.ipv4)
                        bits.push(Net.ipv4);
                    return bits.join(" · ");
                }
                color: Theme.surfaceFgDim
                font.pixelSize: Appearance.font.size.small
                font.weight: Font.Normal
                elide: Text.ElideRight
            }
        }
    }

    // ── Networks ──
    MenuSeparator {
        width: parent.width
    }

    Item {
        visible: Networking.wifiEnabled
        width: parent.width
        height: Appearance.s(28)

        StyledText {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Networks"
            color: Theme.surfaceFgDim
            font.pixelSize: Appearance.font.size.small
        }

        Item {
            id: refreshBtn

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Appearance.s(26)
            height: Appearance.s(26)

            StateLayer {
                radius: width / 2
                color: Theme.surfaceFg
                onClicked: Net.rescan()
            }

            FIcon {
                anchors.centerIn: parent
                icon: "arrow_clockwise"
                font.pixelSize: Appearance.font.size.normal
                color: Net.scanning ? Theme.accent : Theme.surfaceFgDim

                RotationAnimator on rotation {
                    running: Net.scanning
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                    onRunningChanged: {
                        if (!running)
                            target.rotation = 0;
                    }
                }
            }
        }
    }

    StyledText {
        visible: !Networking.wifiEnabled
        height: Appearance.sizes.menuRowHeight
        text: "Wi-Fi is off"
        color: Theme.surfaceFgDim
    }

    ListView {
        id: netList

        width: parent.width
        // Grow with the content up to maxVisibleRows, then scroll.
        height: Math.min(contentHeight, root.maxVisibleRows * Appearance.sizes.menuRowHeight)
        visible: Networking.wifiEnabled && root.networks.length > 0
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        model: ScriptModel {
            values: Networking.wifiEnabled ? root.networks : []
        }

        WheelScroll {
            view: netList
        }

        delegate: Item {
            id: netItem

            required property var modelData

            // No enum-name dependency: 0 is "no security" in practice.
            readonly property bool secure: (modelData.security ?? 0) !== 0
            readonly property bool expanded: root.pskFor === modelData.name
            readonly property bool failed: root.failedFor === modelData.name

            width: netList.width
            height: Appearance.sizes.menuRowHeight + (expanded ? Appearance.s(42) : 0) + (failed ? Appearance.s(18) : 0)

            Item {
                id: netRow

                width: parent.width
                height: Appearance.sizes.menuRowHeight

                StateLayer {
                    radius: Appearance.rounding.normal
                    color: Theme.surfaceFg
                    onClicked: {
                        root.failedFor = "";
                        if (netItem.modelData.known || !netItem.secure) {
                            netItem.modelData.connect();
                            root.pskFor = "";
                        } else {
                            root.pskFor = netItem.expanded ? "" : netItem.modelData.name;
                        }
                    }
                }

                FIcon {
                    id: netGlyph

                    x: Appearance.s(8)
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "wifi"
                    color: root.strengthPct(netItem.modelData) >= 40 ? Theme.surfaceFg : Theme.surfaceFgDim
                }

                StyledText {
                    anchors.left: netGlyph.right
                    anchors.leftMargin: Appearance.s(10)
                    anchors.right: netTrailing.left
                    anchors.rightMargin: Appearance.s(8)
                    anchors.verticalCenter: parent.verticalCenter
                    text: netItem.modelData.name
                    color: Theme.surfaceFg
                    elide: Text.ElideRight
                }

                Row {
                    id: netTrailing

                    anchors.right: parent.right
                    anchors.rightMargin: Appearance.s(10)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.s(6)

                    StyledText {
                        visible: netItem.modelData.stateChanging ?? false
                        anchors.verticalCenter: parent.verticalCenter
                        text: "…"
                        color: Theme.surfaceFgDim
                    }

                    // Saved network — tapping it just connects.
                    FIcon {
                        visible: netItem.modelData.known ?? false
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "star_fill"
                        font.pixelSize: Appearance.font.size.small
                        color: Theme.accent
                    }

                    // Only for networks that will actually prompt — a lock on a
                    // saved network would read as "needs a password" when it
                    // doesn't.
                    FIcon {
                        visible: netItem.secure && !netItem.modelData.known
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "lock_fill"
                        font.pixelSize: Appearance.font.size.small
                        color: Theme.surfaceFgDim
                    }
                }
            }

            Rectangle {
                id: pskBox

                anchors.top: netRow.bottom
                anchors.topMargin: Appearance.s(4)
                x: Appearance.s(8)
                visible: netItem.expanded
                width: parent.width - Appearance.s(16)
                height: Appearance.s(34)
                radius: height / 2
                color: Theme.surfaceHoverBg

                onVisibleChanged: {
                    if (visible)
                        psk.forceActiveFocus();
                }

                TextInput {
                    id: psk

                    anchors.fill: parent
                    anchors.leftMargin: Appearance.s(14)
                    anchors.rightMargin: Appearance.s(14)
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: Theme.surfaceFg
                    font.family: Appearance.font.family
                    font.pixelSize: Appearance.font.size.normal
                    onAccepted: {
                        netItem.modelData.connectWithPsk(text);
                        root.pskFor = "";
                        text = "";
                    }

                    StyledText {
                        visible: !psk.text
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Password…"
                        color: Theme.surfaceFgDim
                    }
                }
            }

            StyledText {
                anchors.top: netItem.expanded ? pskBox.bottom : netRow.bottom
                x: Appearance.s(8)
                visible: netItem.failed
                text: "Connection failed"
                color: Theme.urgent
                font.pixelSize: Appearance.font.size.small
            }

            Connections {
                target: netItem.modelData

                function onConnectionFailed() {
                    root.failedFor = netItem.modelData.name;
                }
            }
        }

        // Thin scroll indicator — only while there's more than fits.
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: Appearance.s(2)
            width: Appearance.s(3)
            radius: width / 2
            color: Qt.alpha(Theme.surfaceFg, 0.28)
            visible: netList.interactive
            height: netList.height * (netList.height / Math.max(netList.contentHeight, 1))
            y: netList.contentY * (netList.height / Math.max(netList.contentHeight, 1))
        }
    }

    // Reserve space for scan results so the menu opens at a stable size
    // instead of visibly growing as networks trickle in.
    Item {
        visible: Networking.wifiEnabled && root.networks.length < 3
        width: parent.width
        height: (3 - root.networks.length) * Appearance.sizes.menuRowHeight

        StyledText {
            anchors.centerIn: parent
            text: "Scanning…"
            color: Theme.surfaceFgDim
        }
    }

    // ── Ethernet ──
    MenuSeparator {
        visible: Net.ethernetDevices.length > 0
        width: parent.width
    }

    Repeater {
        model: ScriptModel {
            values: Net.ethernetDevices
        }

        Item {
            required property var modelData

            width: parent.width
            height: Appearance.sizes.menuRowHeight

            StateLayer {
                radius: Appearance.rounding.normal
                color: Theme.surfaceFg
                onClicked: {
                    if (parent.modelData.connected)
                        parent.modelData.disconnect();
                }
            }

            FIcon {
                id: ethGlyph

                x: Appearance.s(8)
                anchors.verticalCenter: parent.verticalCenter
                icon: "globe"
                color: parent.modelData.connected ? Theme.surfaceFg : Theme.surfaceFgDim
            }

            StyledText {
                anchors.left: ethGlyph.right
                anchors.leftMargin: Appearance.s(10)
                anchors.verticalCenter: parent.verticalCenter
                text: parent.modelData.name
                color: Theme.surfaceFg
            }

            StyledText {
                anchors.right: parent.right
                anchors.rightMargin: Appearance.s(10)
                anchors.verticalCenter: parent.verticalCenter
                text: parent.modelData.connected ? "connected" : "off"
                color: parent.modelData.connected ? Theme.ok : Theme.surfaceFgDim
                font.pixelSize: Appearance.font.size.small
            }
        }
    }

    // ── Tailscale ──
    MenuSeparator {
        width: parent.width
    }

    Item {
        width: parent.width
        height: Appearance.sizes.menuRowHeight

        FIcon {
            id: tsGlyph

            x: Appearance.s(8)
            anchors.verticalCenter: parent.verticalCenter
            icon: "lock_shield_fill"
            color: Tailscale.up ? Theme.accent : Theme.surfaceFgDim
        }

        StyledText {
            anchors.left: tsGlyph.right
            anchors.leftMargin: Appearance.s(10)
            anchors.verticalCenter: parent.verticalCenter
            text: "Tailscale"
            color: Theme.surfaceFg
        }

        StyledText {
            anchors.right: tsSwitch.left
            anchors.rightMargin: Appearance.s(10)
            anchors.verticalCenter: parent.verticalCenter
            visible: Tailscale.busy
            text: "…"
            color: Theme.surfaceFgDim
        }

        StyledSwitch {
            id: tsSwitch

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: Tailscale.up
            onToggled: Tailscale.toggle()
        }
    }

    // ── VPN ──
    MenuSeparator {
        visible: Vpn.connections.length > 0
        width: parent.width
    }

    Repeater {
        model: ScriptModel {
            values: Vpn.connections
        }

        Item {
            required property var modelData

            width: parent.width
            height: Appearance.sizes.menuRowHeight

            FIcon {
                id: vpnGlyph

                x: Appearance.s(8)
                anchors.verticalCenter: parent.verticalCenter
                icon: "shield_lefthalf_fill"
                color: parent.modelData.active ? Theme.accent : Theme.surfaceFgDim
            }

            StyledText {
                anchors.left: vpnGlyph.right
                anchors.leftMargin: Appearance.s(10)
                anchors.right: vpnSwitch.left
                anchors.rightMargin: Appearance.s(8)
                anchors.verticalCenter: parent.verticalCenter
                text: parent.modelData.name
                color: Theme.surfaceFg
                elide: Text.ElideRight
            }

            StyledSwitch {
                id: vpnSwitch

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: parent.modelData.active
                onToggled: Vpn.toggle(parent.modelData)
            }
        }
    }
}
