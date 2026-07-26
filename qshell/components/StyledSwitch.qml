import QtQuick
import qs.config

// Stateless switch: renders `checked`, emits toggled(next) — the caller
// flips the backend and the binding reflects it back.
Item {
    id: root

    property bool checked: false

    signal toggled(bool checked)

    implicitWidth: Appearance.s(38)
    implicitHeight: Appearance.s(21)

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.accent : Qt.alpha(Theme.surfaceFg, 0.22)

        Behavior on color {
            CAnim {}
        }
    }

    // Knob stays white in both states (macOS style).
    Rectangle {
        readonly property int pad: Appearance.s(3)

        width: parent.height - pad * 2
        height: width
        radius: width / 2
        y: pad
        x: root.checked ? parent.width - width - pad : pad
        color: "#ffffff"
        border.width: 1
        border.color: "#14000000"

        Behavior on x {
            Anim {
                curve: Appearance.anim.curves.emphasized
                duration: Appearance.anim.durations.small
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
