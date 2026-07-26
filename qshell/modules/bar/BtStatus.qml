import QtQuick
import Quickshell.Bluetooth
import qs.config
import qs.components

// Bluetooth glyph (off / on / connected); click opens the device menu.
Item {
    id: root

    property var popouts: null

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter?.enabled ?? false
    readonly property int connectedCount: Bluetooth.devices.values.filter(d => d.connected).length

    implicitWidth: glyph.implicitWidth + Appearance.sizes.modulePad
    implicitHeight: Appearance.sizes.barInner

    StateLayer {
        onClicked: root.popouts?.toggle("bluetooth", root)
    }

    NIcon {
        id: glyph

        anchors.centerIn: parent
        text: !root.on ? "󰂲" : root.connectedCount > 0 ? "󰂱" : "󰂯"
        color: root.on ? Theme.barFg : Theme.barFgDim
    }
}
