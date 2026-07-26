import QtQuick
import qs.config
import qs.components

// Control Center trigger (macOS toggles glyph).
Item {
    id: root

    property var popouts: null

    implicitWidth: glyph.implicitWidth + Appearance.sizes.modulePad
    implicitHeight: Appearance.sizes.barInner

    StateLayer {
        onClicked: root.popouts?.toggle("control", root)
    }

    FIcon {
        id: glyph

        anchors.centerIn: parent
        icon: "slider_horizontal_3"
    }
}
