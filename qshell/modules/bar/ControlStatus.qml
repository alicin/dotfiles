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
        hitSlop: Appearance.sizes.barSlop
        // Explicit "" page: `context` persists between opens, so without it the
        // panel would reopen on whichever page IPC last asked for.
        onClicked: root.popouts?.openControl("", root)
        // macOS menubar: once any bar menu is open, sliding along the bar
        // switches menus without another click.
        onContainsMouseChanged: {
            if (containsMouse && root.popouts?.open && root.popouts.current !== "control")
                root.popouts.openControl("", root);
        }
    }

    // Vertical slop only, via the wrapper: a handler `margin` extends every
    // side, and the horizontal bleed stole scrolls made over the battery
    // module's edge next door.
    Item {
        anchors.fill: parent
        anchors.topMargin: -Appearance.sizes.barSlop
        anchors.bottomMargin: -Appearance.sizes.barSlop

        WheelDetent {
            // 4% per mouse notch, and the same 4% spread smoothly across a
            // touchpad flick — the fixed step per raw event slammed the
            // volume, since one flick is dozens of events.
            onMoved: notches => {
                Audio.setVolume(Audio.volume + notches * 0.04);
                // Asked for explicitly: setVolume marks the change as the
                // shell's own, which is what stops a Control Center slider
                // drag from summoning an OSD over the slider you're already
                // looking at. Scrolling the bar has no such visible control,
                // so it needs one.
                Osd.show("volume");
            }
        }
    }

    FIcon {
        id: glyph

        anchors.centerIn: parent
        icon: "equal_square_fill"
    }
}
