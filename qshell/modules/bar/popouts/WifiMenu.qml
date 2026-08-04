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

    // What tapping a network row does — shared by mouse and keyboard nav.
    function rowClicked(net: var): void {
        // Mid-connect the row is deliberately frozen; an impatient second
        // click/Enter must not collapse it or stack a duplicate connect.
        if (net.stateChanging ?? false)
            return;
        root.failedFor = "";
        if (net.known || (net.security ?? 0) === 0) {
            net.connect();
            root.pskFor = "";
        } else {
            root.pskFor = root.pskFor === net.name ? "" : net.name;
        }
    }

    // Keyboard nav over the network list (arrows + Enter via the Popouts
    // FocusScope). Enter mirrors a click: connect, or open the password row —
    // which then takes text focus, so typing and Esc behave as expected.
    function navMove(d: int): void {
        if (!netList.visible || netList.count === 0)
            return;
        netList.currentIndex = Math.max(0, Math.min(netList.count - 1, netList.currentIndex + d));
        netList.positionViewAtIndex(netList.currentIndex, ListView.Contain);
    }

    function navActivate(): void {
        const net = root.networks[netList.currentIndex];
        if (!net)
            return;
        root.rowClicked(net);
        // Re-position after the psk row has expanded the delegate — on the
        // last visible row the password field otherwise opens below the clip
        // and takes focus while invisible.
        Qt.callLater(() => netList.positionViewAtIndex(netList.currentIndex, ListView.Contain));
    }

    Component.onCompleted: {
        // rescan() rather than bare scannerEnabled: it also raises
        // Net.scanning, which is what keeps the filler text below honest.
        Net.rescan();
        Vpn.refresh();
        Tailscale.refresh();
    }

    Component.onDestruction: Net.stopScan()

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
                    // try, not a null-check: stopScan() on menu close flips
                    // this false mid-teardown, and the glyph can be a
                    // destroyed-but-non-null wrapper by then — the write
                    // itself throws.
                    onRunningChanged: {
                        try {
                            if (!running)
                                target.rotation = 0;
                        } catch (e) {}
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
        // No phantom selection until the keyboard asks for one.
        currentIndex: -1
        highlightMoveDuration: Appearance.anim.durations.expressiveFastEffects
        highlightResizeDuration: Appearance.anim.durations.expressiveFastEffects

        highlight: Rectangle {
            radius: Appearance.rounding.normal
            color: Theme.surfaceHoverBg
        }

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
                    onClicked: root.rowClicked(netItem.modelData)
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

                // Mid-connect the row stays open with the field frozen, so
                // success/failure lands somewhere visible instead of the row
                // collapsing on submit and "…" being the whole story.
                readonly property bool connecting: netItem.modelData.stateChanging ?? false
                property bool reveal: false

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

                function submit(): void {
                    if (!psk.text || pskBox.connecting)
                        return;
                    root.failedFor = "";
                    // Text and row survive the attempt — a failure comes back
                    // to an editable field, not a collapsed one.
                    netItem.modelData.connectWithPsk(psk.text);
                }

                TextInput {
                    id: psk

                    anchors.fill: parent
                    anchors.leftMargin: Appearance.s(14)
                    anchors.rightMargin: trailing.width + Appearance.s(18)
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: pskBox.reveal ? TextInput.Normal : TextInput.Password
                    enabled: !pskBox.connecting
                    color: Theme.surfaceFg
                    font.family: Appearance.font.family
                    font.pixelSize: Appearance.font.size.normal
                    // Backing out of the password shouldn't cost the whole
                    // menu — that Esc is scoped to the row; the next one (from
                    // the panel FocusScope) closes the popout.
                    Keys.onEscapePressed: root.pskFor = ""
                    // A single-line TextInput does NOT consume arrows or
                    // Return — they'd bubble to the FocusScope's nav handlers
                    // (Return via onAccepted would fire twice: submit here,
                    // then navActivate collapsing this very row). Keys
                    // handlers run first and accept by default.
                    Keys.onUpPressed: event => event.accepted = true
                    Keys.onDownPressed: event => event.accepted = true
                    Keys.onReturnPressed: pskBox.submit()
                    Keys.onEnterPressed: pskBox.submit()

                    StyledText {
                        visible: !psk.text
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Password…"
                        color: Theme.surfaceFgDim
                    }
                }

                Row {
                    id: trailing

                    anchors.right: parent.right
                    anchors.rightMargin: Appearance.s(8)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.s(2)

                    StyledText {
                        visible: pskBox.connecting
                        anchors.verticalCenter: parent.verticalCenter
                        text: "…"
                        color: Theme.surfaceFgDim
                    }

                    Item {
                        width: Appearance.s(24)
                        height: Appearance.s(24)

                        StateLayer {
                            radius: width / 2
                            color: Theme.surfaceFg
                            onClicked: {
                                pskBox.reveal = !pskBox.reveal;
                                psk.forceActiveFocus();
                            }
                        }

                        FIcon {
                            anchors.centerIn: parent
                            icon: pskBox.reveal ? "eye_slash_fill" : "eye_fill"
                            font.pixelSize: Appearance.font.size.normal
                            color: Theme.surfaceFgDim
                        }
                    }

                    Item {
                        visible: !pskBox.connecting
                        width: Appearance.s(24)
                        height: Appearance.s(24)

                        StateLayer {
                            radius: width / 2
                            color: Theme.surfaceFg
                            onClicked: pskBox.submit()
                        }

                        FIcon {
                            anchors.centerIn: parent
                            icon: "arrow_right_circle_fill"
                            font.pixelSize: Appearance.font.size.normal
                            color: psk.text ? Theme.accent : Theme.surfaceFgDim
                        }
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
                    // A stale saved password (router changed, hotel rotated
                    // it) otherwise retries the same credential forever with
                    // no way to type a new one.
                    if (netItem.secure)
                        root.pskFor = netItem.modelData.name;
                }

                function onConnectedChanged() {
                    if (netItem.modelData.connected && root.pskFor === netItem.modelData.name) {
                        root.pskFor = "";
                        root.failedFor = "";
                    }
                }
            }
        }

        // Thin scroll indicator — only while there's more than fits.
        // Explicitly parented to the viewport: children declared inside a
        // Flickable get reparented to contentItem and scroll away with it.
        Rectangle {
            parent: netList
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
            // Only claim to scan while actually scanning — in a sparse RF
            // environment this used to say "Scanning…" forever.
            text: !Net.wifi ? "No Wi-Fi adapter" : Net.scanning ? "Scanning…" : "No other networks"
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

        // A switch, like the VPN rows below — the old row had a full hover
        // affordance whose only action was disconnect, and once down it
        // offered no way back up.
        Item {
            id: ethRow

            required property var modelData

            width: parent.width
            height: Appearance.sizes.menuRowHeight

            FIcon {
                id: ethGlyph

                x: Appearance.s(8)
                anchors.verticalCenter: parent.verticalCenter
                icon: "globe"
                color: ethRow.modelData.connected ? Theme.surfaceFg : Theme.surfaceFgDim
            }

            StyledText {
                anchors.left: ethGlyph.right
                anchors.leftMargin: Appearance.s(10)
                anchors.right: ethSwitch.left
                anchors.rightMargin: Appearance.s(8)
                anchors.verticalCenter: parent.verticalCenter
                text: ethRow.modelData.name
                color: Theme.surfaceFg
                elide: Text.ElideRight
            }

            StyledSwitch {
                id: ethSwitch

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: ethRow.modelData.connected
                onToggled: checked => {
                    if (checked)
                        Net.connectDevice(ethRow.modelData.name);
                    else
                        ethRow.modelData.disconnect();
                }
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

        Column {
            anchors.left: tsGlyph.right
            anchors.leftMargin: Appearance.s(10)
            anchors.right: tsBusy.visible ? tsBusy.left : tsSwitch.left
            anchors.rightMargin: Appearance.s(8)
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                width: parent.width
                text: "Tailscale"
                color: Theme.surfaceFg
                elide: Text.ElideRight
            }

            // NeedsLogin, a stopped daemon and a missing CLI used to render
            // identically to a clean "off" — a switch that just wouldn't move.
            StyledText {
                width: parent.width
                visible: text !== ""
                text: Tailscale.stateLabel
                color: Theme.surfaceFgDim
                font.pixelSize: Appearance.font.size.small
                font.weight: Font.Normal
                elide: Text.ElideRight
            }
        }

        StyledText {
            id: tsBusy

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

    // A toggle whose ~30s settle window expired with nothing happening —
    // most likely a dismissed pkexec prompt.
    StyledText {
        visible: Tailscale.lastError !== ""
        x: Appearance.s(8)
        width: parent.width - Appearance.s(16)
        text: Tailscale.lastError
        color: Theme.urgent
        font.pixelSize: Appearance.font.size.small
        elide: Text.ElideRight
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
            id: vpnRow

            required property var modelData

            readonly property bool busy: Vpn.busyFor === modelData.name
            readonly property bool failed: Vpn.failedFor === modelData.name

            width: parent.width
            height: Appearance.sizes.menuRowHeight + (failed ? Appearance.s(18) : 0)

            FIcon {
                id: vpnGlyph

                x: Appearance.s(8)
                y: (Appearance.sizes.menuRowHeight - height) / 2
                icon: "shield_lefthalf_fill"
                color: vpnRow.modelData.active ? Theme.accent : Theme.surfaceFgDim
            }

            StyledText {
                anchors.left: vpnGlyph.right
                anchors.leftMargin: Appearance.s(10)
                anchors.right: vpnBusy.visible ? vpnBusy.left : vpnSwitch.left
                anchors.rightMargin: Appearance.s(8)
                anchors.verticalCenter: vpnGlyph.verticalCenter
                text: vpnRow.modelData.name
                color: Theme.surfaceFg
                elide: Text.ElideRight
            }

            StyledText {
                id: vpnBusy

                anchors.right: vpnSwitch.left
                anchors.rightMargin: Appearance.s(10)
                anchors.verticalCenter: vpnGlyph.verticalCenter
                visible: vpnRow.busy
                text: "…"
                color: Theme.surfaceFgDim
            }

            StyledSwitch {
                id: vpnSwitch

                anchors.right: parent.right
                anchors.verticalCenter: vpnGlyph.verticalCenter
                checked: vpnRow.modelData.active
                // One at a time — the service refuses a second toggle
                // mid-flight anyway; don't render a switch that looks willing.
                enabled: Vpn.busyFor === ""
                onToggled: Vpn.toggle(vpnRow.modelData)
            }

            // nmcli's first error line (missing secrets, unreachable
            // endpoint) — the exit status used to be thrown away entirely.
            StyledText {
                visible: vpnRow.failed
                x: Appearance.s(8)
                width: parent.width - Appearance.s(16)
                anchors.bottom: parent.bottom
                text: Vpn.failedMsg || "Failed"
                color: Theme.urgent
                font.pixelSize: Appearance.font.size.small
                elide: Text.ElideRight
            }
        }
    }
}
