import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.config
import qs.components

// Adapter toggle, paired devices (connect/disconnect, battery, forget) and a
// discovery mode that lists nearby unpaired devices to pair with.
Column {
    id: root

    // Rows past this scroll instead of growing the menu.
    readonly property int maxVisibleRows: 6

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
            return "pairing…";
        if (d.connected)
            return d.batteryAvailable ? `connected · ${Math.round(d.battery * 100)}%` : "connected";
        return d.bonded || d.paired ? "paired" : "";
    }

    width: Appearance.s(340)
    spacing: Appearance.s(2)

    // Discovery is a battery/radio cost — never leave ours running behind us.
    Component.onDestruction: {
        if (root.startedDiscovery && (root.adapter?.discovering ?? false))
            root.adapter.discovering = false;
    }

    // Pill button for the per-device action row.
    component ActionChip: Rectangle {
        id: chip

        property string label: ""
        property string glyph: ""
        property color fg: Theme.surfaceFg

        signal tapped

        implicitWidth: chipRow.implicitWidth + Appearance.s(20)
        implicitHeight: Appearance.s(28)
        radius: height / 2
        color: Theme.surfaceHoverBg

        StateLayer {
            radius: chip.radius
            color: chip.fg
            onClicked: chip.tapped()
        }

        Row {
            id: chipRow

            anchors.centerIn: parent
            spacing: Appearance.s(5)

            FIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: chip.glyph
                font.pixelSize: Appearance.font.size.small
                color: chip.fg
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                color: chip.fg
                font.pixelSize: Appearance.font.size.small
            }
        }
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
        height: Appearance.sizes.menuRowHeight

        StateLayer {
            radius: Appearance.rounding.normal
            color: Theme.surfaceFg
            onClicked: row.tapped()
        }

        Item {
            id: rowGlyph

            readonly property var g: root.glyphFor(row.dev)

            x: Appearance.s(8)
            width: Appearance.s(22)
            height: parent.height

            FIcon {
                visible: rowGlyph.g[1]
                anchors.centerIn: parent
                icon: rowGlyph.g[1] ? rowGlyph.g[0] : ""
                color: row.dev.connected ? Theme.accent : Theme.surfaceFg
            }

            NIcon {
                visible: !rowGlyph.g[1]
                anchors.centerIn: parent
                text: rowGlyph.g[1] ? "" : rowGlyph.g[0]
                color: row.dev.connected ? Theme.accent : Theme.surfaceFg
            }
        }

        Column {
            anchors.left: rowGlyph.right
            anchors.leftMargin: Appearance.s(10)
            anchors.right: rowTrailing.left
            anchors.rightMargin: Appearance.s(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            StyledText {
                width: parent.width
                text: row.dev.name || row.dev.deviceName || row.dev.address
                color: Theme.surfaceFg
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

        Row {
            id: rowTrailing

            anchors.right: parent.right
            anchors.rightMargin: Appearance.s(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.s(6)

            FIcon {
                visible: row.dev.connected
                anchors.verticalCenter: parent.verticalCenter
                icon: "checkmark_alt"
                color: Theme.accent
            }

            FIcon {
                visible: row.expandable
                anchors.verticalCenter: parent.verticalCenter
                icon: row.expanded ? "chevron_up" : "chevron_down"
                font.pixelSize: Appearance.font.size.small
                color: Theme.surfaceFgDim
            }
        }
    }

    // ── Adapter ──
    Item {
        width: parent.width
        height: Appearance.sizes.menuRowHeight

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: "Bluetooth"
            color: Theme.surfaceFg
        }

        StyledSwitch {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: root.on
            onToggled: checked => {
                if (root.adapter)
                    root.adapter.enabled = checked;
            }
        }
    }

    MenuSeparator {
        width: parent.width
    }

    StyledText {
        visible: !root.on
        height: Appearance.sizes.menuRowHeight
        text: "Bluetooth is off"
        color: Theme.surfaceFgDim
    }

    // ── Paired devices ──
    StyledText {
        visible: root.on && root.known.length === 0
        height: Appearance.sizes.menuRowHeight
        text: "No paired devices"
        color: Theme.surfaceFgDim
    }

    ListView {
        id: knownList

        width: parent.width
        height: Math.min(contentHeight, root.maxVisibleRows * Appearance.sizes.menuRowHeight)
        visible: root.on && root.known.length > 0
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        model: ScriptModel {
            values: root.on ? root.known : []
        }

        WheelScroll {
            view: knownList
        }

        delegate: Column {
            id: knownItem

            required property var modelData

            readonly property bool expanded: root.expandedAddr === modelData.address

            width: knownList.width

            DeviceRow {
                dev: knownItem.modelData
                expanded: knownItem.expanded
                expandable: true
                onTapped: root.expandedAddr = knownItem.expanded ? "" : knownItem.modelData.address
            }

            // Action row — kept behind a tap so a mis-click can't unpair.
            Row {
                visible: knownItem.expanded
                height: visible ? Appearance.s(36) : 0
                x: Appearance.s(38)
                spacing: Appearance.s(6)

                ActionChip {
                    label: knownItem.modelData.connected ? "Disconnect" : "Connect"
                    glyph: knownItem.modelData.connected ? "xmark_circle_fill" : "link"
                    onTapped: {
                        if (knownItem.modelData.connected)
                            knownItem.modelData.disconnect();
                        else
                            knownItem.modelData.connect();
                    }
                }

                ActionChip {
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

    // ── Discovery ──
    MenuSeparator {
        visible: root.on
        width: parent.width
    }

    Item {
        visible: root.on
        width: parent.width
        height: Appearance.sizes.menuRowHeight

        FIcon {
            id: scanGlyph

            x: Appearance.s(8)
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
            anchors.leftMargin: Appearance.s(10)
            anchors.verticalCenter: parent.verticalCenter
            text: root.discovering ? "Searching…" : "Add a device"
            color: Theme.surfaceFg
        }

        StyledSwitch {
            anchors.right: parent.right
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
        visible: root.on && root.discovering && root.nearby.length === 0
        height: Appearance.sizes.menuRowHeight
        text: "No devices found yet"
        color: Theme.surfaceFgDim
    }

    ListView {
        id: nearbyList

        width: parent.width
        height: Math.min(contentHeight, root.maxVisibleRows * Appearance.sizes.menuRowHeight)
        visible: root.on && root.discovering && root.nearby.length > 0
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        model: ScriptModel {
            values: root.on && root.discovering ? root.nearby : []
        }

        WheelScroll {
            view: nearbyList
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
