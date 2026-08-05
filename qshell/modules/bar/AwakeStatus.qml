import QtQuick
import qs.config
import qs.components
import qs.services

// Keep Awake's own bar module: a coffee cup, up only while the toggle is
// holding the machine open.
//
// It began as a pink tint on the Control Center glyph next door, which said
// *something* had changed without saying what, and spent a colour on the one
// module that has another reason to change colour. A module of its own
// instead: the cup names the state, and clicking it hands the machine back to
// its idle timers without opening anything.
Item {
    id: root

    property var tooltip: null

    // `inhibited`, not `active`: a recording holds the machine open too, but
    // that has its own always-up module further along the row, and two lights
    // for one fact only make you work out which is which.
    readonly property bool awake: Idle.inhibited

    // Collapses to nothing when off, the way the privacy lights do — the state
    // is off nearly all the time, and a permanently reserved slot for it would
    // be a gap the eye has to learn to skip.
    //
    // A square barInner rather than the cup's own implicitWidth: a root
    // binding that reaches forward to a child id throws at creation if it
    // resolves on the very first pass (which this one does whenever the shell
    // starts up already inhibited), and a binding that throws never registers
    // its dependency — it would stay 0 for the whole session.
    implicitWidth: awake ? Appearance.sizes.barInner : 0
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
        color: Theme.barAwake
        // Both the warning and the switch that clears it, like the mic light.
        // The panel is still the place to turn it *on*; this only exists while
        // it's on, so the only thing left to want from it is off.
        onClicked: Idle.toggle()
        onContainsMouseChanged: {
            if (containsMouse)
                root.tooltip?.show("Keep Awake — click to let it sleep again", root);
            else
                root.tooltip?.hide(root);
        }
    }

    NIcon {
        id: cup

        anchors.centerIn: parent
        // Nerd-font: Framework7 ships no cup. `barAwake` rather than the mauve
        // accent, so that if the bar ever does tint the module owning an open
        // menu, this doesn't turn into the same colour saying something else.
        text: ""
        font.pixelSize: Appearance.s(14)
        color: Theme.barAwake
        // Fades and scales in rather than snapping into a gap the width
        // animation is still opening — the privacy lights' appear.
        opacity: root.awake ? 1 : 0
        scale: root.awake ? 1 : 0.55

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
