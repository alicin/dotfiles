import QtQuick
import qs.config
import qs.components
import qs.services

// Control Center trigger (macOS toggles glyph).
//
// Scroll adjusts volume: the speaker module that used to own that gesture is a
// Control Center page now, and losing a working wheel-over-the-bar shortcut to
// a reorganisation would be a straight downgrade.
Item {
    id: root

    property var popouts: null

    implicitWidth: glyph.implicitWidth + Appearance.sizes.modulePad
    implicitHeight: Appearance.sizes.barInner

    StateLayer {
        // Explicit "" page: `context` persists between opens, so without it the
        // panel would reopen on whichever page IPC last asked for.
        onClicked: root.popouts?.openControl("", root)
    }

    WheelHandler {
        onWheel: event => {
            Audio.setVolume(Audio.volume + (event.angleDelta.y > 0 ? 0.04 : -0.04));
            // Asked for explicitly: setVolume marks the change as the shell's
            // own, which is what stops a Control Center slider drag from
            // summoning an OSD over the slider you're already looking at.
            // Scrolling the bar has no such visible control, so it needs one.
            Osd.show("volume");
        }
    }

    FIcon {
        id: glyph

        anchors.centerIn: parent
        icon: "equal_square_fill"
    }
}
