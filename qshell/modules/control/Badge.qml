import QtQuick
import qs.config
import qs.components

// The round icon disc that fronts every Control Center row and tile: accent
// fill when the thing it stands for is on.
//
// Set `toggles` and it becomes its own hit target with its own hover wash —
// that's what lets the Bluetooth row switch the radio while the *rest* of the
// row opens the detail page, the way macOS Control Centre does it.
Item {
    id: root

    property string glyph: "" // Framework7 ligature name
    property string rune: ""  // nerd-font glyph, for what Framework7 lacks
    property bool active: false
    property bool toggles: false
    property real size: Appearance.s(34)

    signal tapped

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.active ? Theme.accent : Qt.alpha(Theme.surfaceFg, 0.14)

        Behavior on color {
            CAnim {}
        }
    }

    FIcon {
        anchors.centerIn: parent
        visible: root.rune === ""
        icon: root.glyph
        font.pixelSize: root.size * 0.47
        color: root.active ? Theme.accentFg : Theme.surfaceFg
    }

    NIcon {
        anchors.centerIn: parent
        visible: root.rune !== ""
        text: root.rune
        // Nerd-font glyphs sit small in their em box; same 6% bump NIcon uses.
        font.pixelSize: Math.round(root.size * 0.47 * 1.06)
        color: root.active ? Theme.accentFg : Theme.surfaceFg
    }

    StateLayer {
        radius: width / 2
        color: root.active ? Theme.accentFg : Theme.surfaceFg
        enabled: root.toggles
        visible: root.toggles
        onClicked: root.tapped()
    }
}
