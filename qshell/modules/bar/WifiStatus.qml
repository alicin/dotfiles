import QtQuick
import qs.config
import qs.components
import qs.services

// Wifi state glyph; click opens the network menu.
Item {
    id: root

    property var popouts: null

    readonly property string icon: {
        if (!Net.wifiEnabled)
            return "wifi_slash";
        if (Net.connected)
            return "wifi";
        if (Net.ethernet)
            return "globe";
        return "wifi_exclamationmark";
    }

    implicitWidth: glyph.implicitWidth + Appearance.sizes.modulePad
    implicitHeight: Appearance.sizes.barInner

    StateLayer {
        onClicked: root.popouts?.toggle("wifi", root)
    }

    FIcon {
        id: glyph

        anchors.centerIn: parent
        icon: root.icon
        color: Net.wifiEnabled && (Net.connected ? Net.strength >= 25 : Net.ethernet) ? Theme.barFg : Theme.barFgDim
    }
}
