import QtQuick
import qs.config

// Small pill button — optional glyph plus a label. Used for the per-device
// actions in the Control Center (connect, forget, ring, send clipboard), where
// a bare icon button left you guessing what it did.
Rectangle {
    id: root

    property string label: ""
    property string glyph: ""
    property color fg: Theme.surfaceFg
    // Sits on top of a card that is already surfaceHoverBg, so the chip needs
    // its own lift rather than the same tint.
    property color bg: Qt.alpha(Theme.surfaceFg, 0.1)

    signal tapped

    implicitWidth: row.implicitWidth + Appearance.s(20)
    implicitHeight: Appearance.s(28)
    radius: height / 2
    color: bg

    Behavior on color {
        CAnim {}
    }

    StateLayer {
        radius: root.radius
        color: root.fg
        onClicked: root.tapped()
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Appearance.s(5)

        FIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.glyph !== ""
            icon: root.glyph
            font.pixelSize: Appearance.font.size.small
            color: root.fg
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: root.fg
            font.pixelSize: Appearance.font.size.small
        }
    }
}
