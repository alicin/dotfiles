import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.config
import qs.components

// Bluetooth page: paired devices (connect / disconnect / forget, with battery
// where the device reports it) and a discovery mode that lists nearby unpaired
// devices to pair with. The adapter switch itself is duplicated on the Control
// Center home row, so the radio is one tap away without coming in here.
Column {
    id: root

    signal back

    // Rows past this scroll instead of growing the panel.
    readonly property int maxVisibleRows: 5

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter?.enabled ?? false
    readonly property bool discovering: adapter?.discovering ?? false

    readonly property var known: [...Bluetooth.devices.values].filter(d => d.paired || d.bonded).sort((a, b) => (b.connected - a.connected) || (a.name ?? "").localeCompare(b.name ?? ""))
    readonly property var nearby: [...Bluetooth.devices.values].filter(d => !d.paired && !d.bonded).sort((a, b) => (a.name ?? "").localeCompare(b.name ?? ""))

    // Address of the device with its action row expanded.
    property string expandedAddr: ""

    // BlueZ's Discovering is adapter-global, not per-client — anything else on
    // the system (a device trying to reconnect, another BT applet) can turn it
    // on while we're closed. Only tear down a scan we actually started.
    property bool startedDiscovery: false

    // [glyph, isF7] — F7 has no bluetooth/mouse/watch glyph, keep nerd runes there.
    function glyphFor(d: var): var {
        const icon = d.icon ?? "";
        if (icon.includes("audio") || icon.includes("headset") || icon.includes("headphone"))
            return ["headphones", true];
        if (icon.includes("keyboard"))
            return ["keyboard", true];
        if (icon.includes("phone"))
            return ["device_phone_portrait", true];
        if (icon.includes("computer"))
            return ["desktopcomputer", true];
        if (icon.includes("video") || icon.includes("display"))
            return ["tv_fill", true];
        if (icon.includes("mouse") || icon.includes("pointing"))
            return ["󰍽", false];
        if (icon.includes("watch"))
            return ["󰢗", false];
        return ["󰂯", false];
    }

    function stateLabel(d: var): string {
        if (d.pairing)
            return "Pairing…";
        // The in-flight states used to render as nothing at all, so a failed
        // connect (headphones off, out of range) looked identical to not
        // having tapped.
        if (d.state === BluetoothDeviceState.Connecting)
            return "Connecting…";
        if (d.state === BluetoothDeviceState.Disconnecting)
            return "Disconnecting…";
        if (d.connected)
            return d.batteryAvailable ? `Connected · ${Math.round(d.battery * 100)}%` : "Connected";
        return d.bonded || d.paired ? "Paired" : "";
    }

    spacing: Appearance.s(8)

    // Discovery is a battery/radio cost — never leave ours running behind us.
    // Leaving the page destroys this, so navigating back stops the scan too.
    Component.onDestruction: {
        if (root.startedDiscovery && (root.adapter?.discovering ?? false))
            root.adapter.discovering = false;
    }

    // Reusable device row: glyph, name, state line, trailing slot, tap action.
    component DeviceRow: Item {
        id: row

        required property var dev
        property bool expanded: false
        // Draws the disclosure chevron. Nearby/unpaired rows are a single
        // action (pair), so they don't get one.
        property bool expandable: false

        signal tapped

        width: ListView.view ? ListView.view.width : parent.width
        height: Appearance.s(44)

        StateLayer {
            radius: Appearance.rounding.normal
            color: Theme.surfaceFg
            onClicked: row.tapped()
        }

        Badge {
            id: rowBadge

            readonly property var g: root.glyphFor(row.dev)

            x: Appearance.s(8)
            anchors.verticalCenter: parent.verticalCenter
            size: Appearance.s(30)
            glyph: g[1] ? g[0] : ""
            rune: g[1] ? "" : g[0]
            active: row.dev.connected
        }

        Column {
            anchors.left: rowBadge.right
            anchors.leftMargin: Appearance.s(10)
            anchors.right: rowTrailing.left
            anchors.rightMargin: Appearance.s(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            StyledText {
                width: parent.width
                text: row.dev.name || row.dev.deviceName || row.dev.address
                color: Theme.surfaceFg
                font.pixelSize: Appearance.font.size.small
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                visible: text !== ""
                text: root.stateLabel(row.dev)
                color: row.dev.connected ? Theme.ok : Theme.surfaceFgDim
                font.pixelSize: Appearance.font.size.small
                font.weight: Font.Normal
                elide: Text.ElideRight
            }
        }

        signal disclosureTapped

        Row {
            id: rowTrailing

            anchors.right: parent.right
            anchors.rightMargin: Appearance.s(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.s(2)

            StyledText {
                visible: row.dev.state === BluetoothDeviceState.Connecting || row.dev.state === BluetoothDeviceState.Disconnecting
                anchors.verticalCenter: parent.verticalCenter
                text: "…"
                color: Theme.surfaceFgDim
            }

            // Its own hit target: the row tap now connects/disconnects, so
            // the way into the expansion (Forget lives there) needs a button.
            Item {
                visible: row.expandable
                width: Appearance.s(26)
                height: Appearance.s(30)
                anchors.verticalCenter: parent.verticalCenter

                StateLayer {
                    radius: Appearance.s(8)
                    color: Theme.surfaceFg
                    onClicked: row.disclosureTapped()
                }

                FIcon {
                    anchors.centerIn: parent
                    icon: row.expanded ? "chevron_up" : "chevron_down"
                    font.pixelSize: Appearance.font.size.small
                    color: Theme.surfaceFgDim
                }
            }
        }
    }

    PageHeader {
        title: "Bluetooth"
        onBack: root.back()

        StyledSwitch {
            anchors.verticalCenter: parent.verticalCenter
            checked: root.on
            onToggled: checked => {
                if (root.adapter)
                    root.adapter.enabled = checked;
            }
        }
    }

    // ── Paired ──
    Card {
        title: root.on ? "My devices" : ""

        StyledText {
            x: Appearance.s(12)
            height: visible ? Appearance.s(28) : 0
            visible: !root.on || root.known.length === 0
            text: root.on ? "No paired devices" : "Bluetooth is off"
            color: Theme.surfaceFgDim
            font.pixelSize: Appearance.font.size.small
            font.weight: Font.Normal
        }

        ListView {
            id: knownList

            width: parent.width
            height: Math.min(contentHeight, root.maxVisibleRows * Appearance.s(44))
            visible: root.on && root.known.length > 0
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            WheelScroll {
                view: knownList
            }

            model: ScriptModel {
                values: root.on ? root.known : []
            }

            delegate: Column {
                id: knownItem

                required property var modelData

                readonly property bool expanded: root.expandedAddr === modelData.address

                // Connecting → Disconnected without ever reaching Connected:
                // the attempt fell through. Rendered as a transient red line,
                // because "nothing happened" was the entire old failure UI.
                property bool wasConnecting: false
                property bool failed: false

                width: knownList.width

                Connections {
                    target: knownItem.modelData

                    function onStateChanged() {
                        const s = knownItem.modelData.state;
                        if (s === BluetoothDeviceState.Connecting) {
                            knownItem.wasConnecting = true;
                            knownItem.failed = false;
                        } else if (s === BluetoothDeviceState.Connected) {
                            knownItem.wasConnecting = false;
                        } else if (s === BluetoothDeviceState.Disconnected && knownItem.wasConnecting) {
                            knownItem.wasConnecting = false;
                            knownItem.failed = true;
                            failClear.restart();
                        }
                    }
                }

                Timer {
                    id: failClear

                    interval: 5000
                    onTriggered: knownItem.failed = false
                }

                // Tap = connect/disconnect (the single most common Bluetooth
                // action was two precise taps deep); the chevron opens the
                // action row, which is where Forget hides from mis-clicks.
                DeviceRow {
                    dev: knownItem.modelData
                    expanded: knownItem.expanded
                    expandable: true
                    onTapped: {
                        if (knownItem.modelData.connected)
                            knownItem.modelData.disconnect();
                        else if (knownItem.modelData.state !== BluetoothDeviceState.Connecting)
                            knownItem.modelData.connect();
                    }
                    onDisclosureTapped: root.expandedAddr = knownItem.expanded ? "" : knownItem.modelData.address
                }

                StyledText {
                    visible: knownItem.failed
                    x: Appearance.s(48)
                    height: visible ? Appearance.s(18) : 0
                    text: "Couldn't connect"
                    color: Theme.urgent
                    font.pixelSize: Appearance.font.size.small
                }

                // Action row — kept behind the chevron so a mis-click can't
                // unpair.
                Row {
                    visible: knownItem.expanded
                    height: visible ? Appearance.s(38) : 0
                    x: Appearance.s(48)
                    spacing: Appearance.s(6)

                    Chip {
                        label: knownItem.modelData.connected ? "Disconnect" : "Connect"
                        glyph: knownItem.modelData.connected ? "xmark_circle_fill" : "link"
                        onTapped: {
                            if (knownItem.modelData.connected)
                                knownItem.modelData.disconnect();
                            else
                                knownItem.modelData.connect();
                        }
                    }

                    Chip {
                        label: "Forget"
                        glyph: "trash"
                        fg: Theme.urgent
                        onTapped: {
                            root.expandedAddr = "";
                            knownItem.modelData.forget();
                        }
                    }
                }
            }
        }
    }

    // ── Discovery ──
    Card {
        visible: root.on

        Item {
            width: parent.width
            height: Appearance.s(40)

            FIcon {
                id: scanGlyph

                x: Appearance.s(14)
                anchors.verticalCenter: parent.verticalCenter
                icon: "arrow_clockwise"
                color: root.discovering ? Theme.accent : Theme.surfaceFgDim

                RotationAnimator on rotation {
                    running: root.discovering
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

            StyledText {
                anchors.left: scanGlyph.right
                anchors.leftMargin: Appearance.s(12)
                anchors.verticalCenter: parent.verticalCenter
                text: root.discovering ? "Searching…" : "Add a device"
                color: Theme.surfaceFg
                font.pixelSize: Appearance.font.size.small
            }

            StyledSwitch {
                anchors.right: parent.right
                anchors.rightMargin: Appearance.s(12)
                anchors.verticalCenter: parent.verticalCenter
                checked: root.discovering
                onToggled: checked => {
                    if (!root.adapter)
                        return;
                    root.adapter.discovering = checked;
                    root.startedDiscovery = checked;
                }
            }
        }

        StyledText {
            x: Appearance.s(14)
            height: visible ? Appearance.s(28) : 0
            visible: root.discovering && root.nearby.length === 0
            text: "No devices found yet"
            color: Theme.surfaceFgDim
            font.pixelSize: Appearance.font.size.small
            font.weight: Font.Normal
        }

        ListView {
            id: nearbyList

            width: parent.width
            height: Math.min(contentHeight, root.maxVisibleRows * Appearance.s(44))
            visible: root.discovering && root.nearby.length > 0
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            WheelScroll {
                view: nearbyList
            }

            model: ScriptModel {
                values: root.on && root.discovering ? root.nearby : []
            }

            delegate: DeviceRow {
                id: nearbyItem

                required property var modelData

                dev: modelData
                // Pairing is the only sensible action on an unknown device; a
                // second tap while it's in flight cancels rather than re-queues.
                onTapped: {
                    if (nearbyItem.modelData.pairing)
                        nearbyItem.modelData.cancelPair();
                    else
                        nearbyItem.modelData.pair();
                }
            }
        }
    }
}
