import QtQuick
import Quickshell
import Quickshell.Networking
import qs.config
import qs.components
import qs.services

// Wi-Fi toggle, current-connection summary (with disconnect/forget), scanned
// networks (scan runs while open, refreshable), plus ethernet devices,
// Tailscale — switch, exit node, tailnet devices — and VPN connections.
Column {
    id: root

    // Rows past this scroll instead of growing the menu.
    readonly property int maxVisibleRows: 6

    // Tighter for the tailnet: it sits under everything else in the menu, and
    // a popout that reaches the bottom of the screen has already lost.
    readonly property int maxPeerRows: 4

    property string pskFor: "" //   ssid with the password row expanded
    property string failedFor: ""

    // ssid whose Forget is armed. Destructive verbs arm on the first tap and
    // fire on the second, the way the Control Center's session buttons do —
    // this one deletes a password that may not be written down anywhere else.
    property string forgetArmed: ""

    property bool exitOpen: false

    // Address the device list last copied, for the row's acknowledgement.
    property string copiedIp: ""

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

    readonly property int peersOnline: Tailscale.peers.filter(p => p.online).length

    // "None" rides in the same list as the eligible peers, so the way back out
    // is where you picked from and "am I on this one" stays one comparison.
    readonly property var exitChoices: [
        {
            name: "None",
            ip: "",
            online: true
        }
    ].concat(Tailscale.exitNodes)

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

    // Delete forgets the highlighted saved network — through the same two
    // presses the trash button needs, so a mis-hit on the way to Backspace
    // can't drop a password.
    function navRemove(): void {
        root.forgetTapped(root.networks[netList.currentIndex]);
    }

    // First tap arms and says so, second one fires. There is no undo: the
    // stored credential is gone and the network goes back to prompting.
    function forgetTapped(net: var): void {
        if (!net?.known)
            return;
        if (root.forgetArmed !== net.name) {
            root.forgetArmed = net.name;
            forgetDisarm.restart();
            return;
        }
        forgetDisarm.stop();
        root.forgetArmed = "";
        // The password row and its failure line belong to a network that is
        // about to stop being saved. Left up, they'd hang over a row that has
        // already re-sorted away as an unknown one — asking for a credential
        // nothing is waiting for.
        if (root.pskFor === net.name)
            root.pskFor = "";
        if (root.failedFor === net.name)
            root.failedFor = "";
        net.forget();
    }

    // Framework7 has nothing tailnet-shaped; these are the closest reading of
    // "what am I looking at".
    function osGlyph(os: string): string {
        switch (os) {
        case "iOS":
        case "android":
            return "device_phone_portrait";
        case "macOS":
            return "device_laptop";
        default:
            return "device_desktop";
        }
    }

    // What the desktop Tailscale clients do when you click a device, and the
    // only thing anyone ever wants off this list (ssh, scp, a URL to open).
    function copyPeer(peer: var): void {
        if (!peer.ip)
            return;
        Quickshell.execDetached(["wl-copy", peer.ip]);
        root.copiedIp = peer.ip;
        copiedClear.restart();
    }

    Timer {
        id: forgetDisarm

        interval: 2500
        onTriggered: root.forgetArmed = ""
    }

    Timer {
        id: copiedClear

        interval: 1400
        onTriggered: root.copiedIp = ""
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
        id: curCard

        readonly property bool armed: root.forgetArmed === Net.ssid

        visible: Networking.wifiEnabled && Net.connected
        width: parent.width
        height: Appearance.s(52) + Appearance.s(38)
        radius: Appearance.rounding.normal
        color: Theme.surfaceHoverBg

        FIcon {
            id: curGlyph

            x: Appearance.s(10)
            y: (Appearance.s(52) - height) / 2
            icon: "wifi"
            color: Theme.accent
        }

        Column {
            anchors.left: curGlyph.right
            anchors.leftMargin: Appearance.s(10)
            anchors.right: parent.right
            anchors.rightMargin: Appearance.s(10)
            anchors.verticalCenter: curGlyph.verticalCenter
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

        // Getting off a network used to mean turning the radio off, and a
        // saved password that had gone stale could only be dropped from
        // outside the shell — which is exactly where you can't get to it.
        Row {
            x: Appearance.s(10)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Appearance.s(8)
            spacing: Appearance.s(6)

            Chip {
                label: "Disconnect"
                glyph: "xmark_circle_fill"
                onTapped: Net.disconnectWifi()
            }

            Chip {
                visible: Net.activeKnown
                label: curCard.armed ? "Sure?" : "Forget"
                glyph: "trash"
                fg: curCard.armed ? Theme.urgent : Theme.surfaceFg
                onTapped: root.forgetTapped(Net.activeNetwork)
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
            readonly property bool armed: root.forgetArmed === modelData.name

            // Hover-revealed, like the clipboard's delete: a trash can parked
            // on every saved row is a lot of standing danger for something you
            // do once a year. The keyboard has no hover, so the highlighted
            // row shows it too — that's where Delete would land.
            readonly property bool showForget: (modelData.known ?? false) && (rowLayer.containsMouse || forgetLayer.containsMouse || armed || netItem.ListView.isCurrentItem)

            width: netList.width
            height: Appearance.sizes.menuRowHeight + (expanded ? Appearance.s(42) : 0) + (failed ? Appearance.s(18) : 0)

            Item {
                id: netRow

                width: parent.width
                height: Appearance.sizes.menuRowHeight

                StateLayer {
                    id: rowLayer

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

                    // An armed trash can says so in words — a glyph that has
                    // quietly gone live is not a confirmation.
                    StyledText {
                        visible: netItem.armed
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Sure?"
                        color: Theme.urgent
                        font.pixelSize: Appearance.font.size.small
                    }

                    // Saved network — tapping it just connects. The star and
                    // the trash can share one slot so the name doesn't reflow
                    // as the row is hovered.
                    Item {
                        visible: netItem.modelData.known ?? false
                        anchors.verticalCenter: parent.verticalCenter
                        width: Appearance.s(24)
                        height: Appearance.s(24)

                        FIcon {
                            anchors.centerIn: parent
                            visible: !netItem.showForget
                            icon: "star_fill"
                            font.pixelSize: Appearance.font.size.small
                            color: Theme.accent
                        }

                        // The button is absent rather than disabled while the
                        // star is up: an invisible MouseArea takes no hover and
                        // no clicks, so the row underneath keeps both.
                        Item {
                            anchors.fill: parent
                            visible: netItem.showForget

                            StateLayer {
                                id: forgetLayer

                                radius: width / 2
                                color: Theme.urgent
                                onClicked: root.forgetTapped(netItem.modelData)
                            }

                            FIcon {
                                anchors.centerIn: parent
                                icon: "trash"
                                font.pixelSize: Appearance.font.size.small
                                color: netItem.armed ? Theme.urgent : Theme.surfaceFgDim
                            }
                        }
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
            // An exit-node write shares this `busy`, and it puts its own "…"
            // on its own row — two of them at once reads as a glitch.
            visible: Tailscale.busy && !Tailscale.exitBusy
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

    // A write whose ~30s settle window expired with nothing happening — most
    // likely a dismissed pkexec prompt.
    StyledText {
        visible: Tailscale.lastError !== ""
        x: Appearance.s(8)
        width: parent.width - Appearance.s(16)
        text: Tailscale.lastError
        color: Theme.urgent
        font.pixelSize: Appearance.font.size.small
        elide: Text.ElideRight
    }

    // Everything below is gated on the daemon actually running: a picker and a
    // device list over a stopped tailscaled is a list of things that can't be
    // clicked, drawn from a netmap that may be days old.
    Item {
        id: exitRow

        visible: Tailscale.up
        width: parent.width
        height: Appearance.sizes.menuRowHeight

        StateLayer {
            radius: Appearance.rounding.normal
            color: Theme.surfaceFg
            onClicked: root.exitOpen = !root.exitOpen
        }

        FIcon {
            id: exitGlyph

            x: Appearance.s(8)
            anchors.verticalCenter: parent.verticalCenter
            icon: "arrow_up_right_square"
            color: Tailscale.exitNode ? Theme.accent : Theme.surfaceFgDim
        }

        StyledText {
            anchors.left: exitGlyph.right
            anchors.leftMargin: Appearance.s(10)
            anchors.verticalCenter: parent.verticalCenter
            text: "Exit node"
            color: Theme.surfaceFg
        }

        // Naming the node in the collapsed row is the point of the row —
        // "routing through somewhere else" is not something to have to go
        // looking for.
        StyledText {
            anchors.right: exitChevron.left
            anchors.rightMargin: Appearance.s(6)
            anchors.verticalCenter: parent.verticalCenter
            text: Tailscale.exitBusy ? "…" : (Tailscale.exitNodeName || "None")
            color: Tailscale.exitNode ? Theme.accent : Theme.surfaceFgDim
            font.pixelSize: Appearance.font.size.small
        }

        FIcon {
            id: exitChevron

            anchors.right: parent.right
            anchors.rightMargin: Appearance.s(10)
            anchors.verticalCenter: parent.verticalCenter
            icon: root.exitOpen ? "chevron_up" : "chevron_down"
            font.pixelSize: Appearance.font.size.small
            color: Theme.surfaceFgDim
        }
    }

    Repeater {
        // With nothing eligible the list would be a single "None" that is
        // already ticked — the line below says the useful thing instead.
        model: ScriptModel {
            values: Tailscale.up && root.exitOpen && Tailscale.exitNodes.length > 0 ? root.exitChoices : []
        }

        Item {
            id: exitItem

            required property var modelData

            readonly property bool current: exitItem.modelData.ip === (Tailscale.exitNode?.ip ?? "")

            width: parent.width
            height: Appearance.s(32)
            // A second pick while the first is still escalating would queue a
            // second polkit prompt; the service refuses it anyway, and a row
            // that looks willing while it isn't is worse than a dead one.
            enabled: !Tailscale.busy

            StateLayer {
                radius: Appearance.rounding.normal
                color: Theme.surfaceFg
                // Re-picking the node you are already on would still escalate,
                // and a polkit prompt for a no-op is the worst kind.
                onClicked: {
                    if (!exitItem.current)
                        Tailscale.setExitNode(exitItem.modelData.ip);
                }
            }

            FIcon {
                x: Appearance.s(16)
                anchors.verticalCenter: parent.verticalCenter
                visible: exitItem.current
                icon: "checkmark_alt"
                font.pixelSize: Appearance.font.size.small
                color: Theme.accent
            }

            StyledText {
                // Anchored on both sides, not positioned with x: the right
                // anchor alone wins over x, which right-aligns the name across
                // a dead gutter and leaves elide with nothing to elide against.
                anchors.left: parent.left
                anchors.leftMargin: Appearance.s(40)
                anchors.right: exitState.left
                anchors.rightMargin: Appearance.s(8)
                anchors.verticalCenter: parent.verticalCenter
                text: exitItem.modelData.name
                color: exitItem.current ? Theme.accent : Theme.surfaceFg
                font.pixelSize: Appearance.font.size.small
                elide: Text.ElideRight
            }

            // An offline node still advertises the option and the CLI still
            // accepts it — the traffic just goes nowhere.
            StyledText {
                id: exitState

                anchors.right: parent.right
                anchors.rightMargin: Appearance.s(10)
                anchors.verticalCenter: parent.verticalCenter
                visible: !exitItem.modelData.online
                text: "offline"
                color: Theme.surfaceFgDim
                font.pixelSize: Appearance.font.size.small
            }
        }
    }

    // Far more often than it is wrong, the picker is simply empty — say which.
    StyledText {
        visible: Tailscale.up && root.exitOpen && Tailscale.exitNodes.length === 0
        x: Appearance.s(16)
        width: parent.width - Appearance.s(26)
        height: Appearance.s(32)
        text: "Nothing on this tailnet offers to be one"
        color: Theme.surfaceFgDim
        font.pixelSize: Appearance.font.size.small
        elide: Text.ElideRight
    }

    // ── Devices ──
    Item {
        visible: Tailscale.up
        width: parent.width
        height: Appearance.s(28)

        StyledText {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Devices"
            color: Theme.surfaceFgDim
            font.pixelSize: Appearance.font.size.small
        }

        StyledText {
            anchors.right: parent.right
            anchors.rightMargin: Appearance.s(10)
            anchors.verticalCenter: parent.verticalCenter
            text: `${root.peersOnline} of ${Tailscale.peers.length} online`
            color: Theme.surfaceFgDim
            font.pixelSize: Appearance.font.size.small
        }
    }

    ListView {
        id: peerList

        width: parent.width
        // Same deal as the networks above: grow to maxPeerRows, then scroll.
        height: Math.min(contentHeight, root.maxPeerRows * Appearance.s(34))
        visible: Tailscale.up && Tailscale.peers.length > 0
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        model: ScriptModel {
            values: Tailscale.up ? Tailscale.peers : []
        }

        WheelScroll {
            view: peerList
        }

        delegate: Item {
            id: peerItem

            required property var modelData

            readonly property bool copied: root.copiedIp === modelData.ip

            width: peerList.width
            height: Appearance.s(34)

            StateLayer {
                radius: Appearance.rounding.normal
                color: Theme.surfaceFg
                onClicked: root.copyPeer(peerItem.modelData)
            }

            FIcon {
                id: peerGlyph

                x: Appearance.s(8)
                anchors.verticalCenter: parent.verticalCenter
                icon: root.osGlyph(peerItem.modelData.os)
                font.pixelSize: Appearance.font.size.normal
                color: peerItem.modelData.online ? Theme.surfaceFg : Theme.surfaceFgDim
            }

            StyledText {
                anchors.left: peerGlyph.right
                anchors.leftMargin: Appearance.s(10)
                anchors.right: peerTrailing.left
                anchors.rightMargin: Appearance.s(8)
                anchors.verticalCenter: parent.verticalCenter
                text: peerItem.modelData.name
                color: peerItem.modelData.online ? Theme.surfaceFg : Theme.surfaceFgDim
                font.pixelSize: Appearance.font.size.small
                elide: Text.ElideRight
            }

            Row {
                id: peerTrailing

                anchors.right: parent.right
                anchors.rightMargin: Appearance.s(10)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.s(6)

                // The row above names the exit node, but this list is where
                // you're looking when you wonder whose machine your traffic is
                // coming out of.
                FIcon {
                    visible: peerItem.modelData.exitActive
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "arrow_up_right_square"
                    font.pixelSize: Appearance.font.size.small
                    color: Theme.accent
                }

                // The acknowledgement is narrower than the address it replaces,
                // and this Row is right-anchored — so without a floor on the
                // width, confirming a copy reflows the device name under the
                // cursor for the whole 1.4s and snaps it back. Chip.qml latches
                // its width through its own flash for exactly this reason.
                Item {
                    id: ipSlot

                    // The address's width, measured whenever the address is
                    // what's showing — so the slot can hold it through the
                    // flash and let go afterwards.
                    property real ipWidth: 0

                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: Math.max(ipText.implicitWidth, ipSlot.ipWidth)
                    implicitHeight: ipText.implicitHeight

                    StyledText {
                        id: ipText

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: peerItem.copied ? "Copied" : peerItem.modelData.ip
                        color: peerItem.copied ? Theme.ok : Theme.surfaceFgDim
                        font.pixelSize: Appearance.font.size.small

                        onImplicitWidthChanged: {
                            if (!peerItem.copied)
                                ipSlot.ipWidth = implicitWidth;
                        }
                    }
                }
            }
        }

        // Thin scroll indicator — only while there's more than fits.
        // Explicitly parented to the viewport: children declared inside a
        // Flickable get reparented to contentItem and scroll away with it.
        Rectangle {
            parent: peerList
            anchors.right: parent.right
            anchors.rightMargin: Appearance.s(2)
            width: Appearance.s(3)
            radius: width / 2
            color: Qt.alpha(Theme.surfaceFg, 0.28)
            visible: peerList.interactive
            height: peerList.height * (peerList.height / Math.max(peerList.contentHeight, 1))
            y: peerList.contentY * (peerList.height / Math.max(peerList.contentHeight, 1))
        }
    }

    StyledText {
        visible: Tailscale.up && Tailscale.peers.length === 0
        x: Appearance.s(8)
        height: Appearance.s(34)
        text: "No other devices"
        color: Theme.surfaceFgDim
        font.pixelSize: Appearance.font.size.small
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
