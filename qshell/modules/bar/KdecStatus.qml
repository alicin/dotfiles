import QtQuick
import qs.config
import qs.components
import qs.services

// KDE Connect phone glyph; dim when no device is reachable. Click opens the
// device menu.
Item {
    id: root

    property var popouts: null

    implicitWidth: glyph.implicitWidth + Appearance.sizes.modulePad
    implicitHeight: Appearance.sizes.barInner

    StateLayer {
        onClicked: {
            KdeConnect.refresh();
            root.popouts?.toggle("kdeconnect", root);
        }
    }

    FIcon {
        id: glyph

        anchors.centerIn: parent
        icon: "device_phone_portrait"
        // Solid white whenever a device is actually up. This read as a
        // permanently washed-out icon until the service moved off
        // kdeconnect-cli text parsing — reachable was never true.
        color: KdeConnect.reachable.length > 0 ? Theme.barFg : Theme.barFgDim
    }
}
