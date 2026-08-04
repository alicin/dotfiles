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

    // Transient acknowledgement: swaps the label (green) for a beat, for
    // fire-and-forget actions that otherwise give zero feedback. The width
    // is latched during the flash so neighbouring chips don't reflow under
    // the cursor when the label shortens.
    property string flashText: ""
    property real lockW: 0

    function flash(t: string): void {
        lockW = width;
        flashText = t;
        flashTimer.restart();
    }

    signal tapped

    Timer {
        id: flashTimer

        interval: 1400
        onTriggered: {
            root.flashText = "";
            root.lockW = 0;
        }
    }

    implicitWidth: Math.max(lockW, row.implicitWidth + Appearance.s(20))
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
            visible: root.glyph !== "" && root.flashText === ""
            icon: root.glyph
            font.pixelSize: Appearance.font.size.small
            color: root.fg
        }

        FIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.flashText !== ""
            icon: "checkmark_alt"
            font.pixelSize: Appearance.font.size.small
            color: Theme.ok
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.flashText || root.label
            color: root.flashText ? Theme.ok : root.fg
            font.pixelSize: Appearance.font.size.small
        }
    }
}
