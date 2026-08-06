import QtQuick
import qs.config
import qs.components
import qs.services

// On-screen keyboard toggle.
//
// The keyboard raises itself when the physical one is unplugged, so this is
// not how you normally get it — it is the override for the two cases the
// automatic rule cannot cover: a docked keyboard you would rather not reach
// for, and a keyboard on screen that is in the way of the thing you are trying
// to read. Both want one tap, and the tap has to be reachable *while the
// keyboard is covering the bottom third of the screen*, which is why it lives
// on the bar and not in the Control Center.
Item {
    id: root

    property var tooltip: null

    // Present whenever the keyboard could plausibly be wanted: in touch mode,
    // or pinned on from settings. On a docked desktop session it collapses to
    // nothing, like the privacy lights. Gone entirely while the setting is
    // "off" — toggle() cannot override that mode, so the button would be a
    // control that visibly does nothing, which is worse than its absence.
    readonly property bool relevant: (Appearance.touch && Settings.osk !== "off") || Settings.osk === "on"

    // Floored to the touch target: at barInner (26-37px) this and the rotate
    // button next door were adjacent sub-floor targets, and a thumb missing
    // the keyboard toggle by half a fingertip rotated the screen instead.
    // touchTarget is 0 outside touch mode, so desktop hosts keep barInner.
    implicitWidth: root.relevant ? Math.max(Appearance.sizes.barInner, Appearance.touchTarget) : 0
    implicitHeight: Appearance.sizes.barInner
    visible: implicitWidth > 0.5

    Behavior on implicitWidth {
        Anim {
            duration: Appearance.anim.durations.expressiveFastSpatial
            curve: Appearance.anim.curves.emphasized
        }
    }

    StateLayer {
        hitSlop: Appearance.sizes.barSlop
        color: Theme.barFg
        onClicked: Osk.toggle()
        onContainsMouseChanged: {
            if (containsMouse)
                root.tooltip?.show(Osk.active ? "Hide the on-screen keyboard" : "Show the on-screen keyboard", root);
            else
                root.tooltip?.hide(root);
        }
    }

    FIcon {
        anchors.centerIn: parent
        icon: "keyboard"
        // Accent while it's up, the way an open menu tints its module: the
        // glyph is the same either way, so the colour is the only thing saying
        // which of the two the tap will do.
        color: Osk.active ? Theme.accent : Theme.barFg
        font.pixelSize: Appearance.sizes.glyph
        opacity: root.relevant ? 1 : 0
        scale: root.relevant ? 1 : 0.55

        Behavior on opacity {
            Anim {
                duration: Appearance.anim.durations.expressiveFastSpatial
            }
        }

        Behavior on scale {
            Anim {
                duration: Appearance.anim.durations.expressiveFastSpatial
                curve: Appearance.anim.curves.expressiveFastSpatial
            }
        }
    }
}
