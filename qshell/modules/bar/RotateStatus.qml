import QtQuick
import qs.config
import qs.components
import qs.services

// Quarter-turn the screen.
//
// This is a *manual* control because it has to be. k3v1n has no accelerometer
// — the AMD sensor hub's HID report descriptor declares an ambient light
// sensor and nothing else (notes/k3v1n.md carries the dump), so there is no
// orientation to read and no daemon that could read it. The autorotate path
// exists in services/Tablet.qml and is wired to iio-sensor-proxy; it will
// simply never fire on this panel.
//
// Rotation goes out through wlr-randr rather than `hyprctl keyword monitor`,
// which is refused outright under the Lua config parser. See
// services/Displays.qml.
Item {
    id: root

    property var tooltip: null

    readonly property var mon: Displays.rotatable
    // NOT `transform`: Item already has a final property of that name (the
    // list of QQuickTransform children), and shadowing a final member is an
    // error rather than an override — the binding would never take.
    readonly property int turn: (root.mon?.transform ?? 0) % 4

    // Touch-target floor — see OskStatus.qml, whose neighbour this is.
    implicitWidth: Appearance.touch ? Math.max(Appearance.sizes.barInner, Appearance.touchTarget) : 0
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
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        // Right-click (and the Control Center's card) go straight back to
        // landscape. Cycling three more times to undo a mis-tap on a screen
        // that is now sideways is a bad minute.
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                Displays.resetRotation();
            else
                Displays.rotate(1);
        }
        onContainsMouseChanged: {
            if (containsMouse)
                root.tooltip?.show(`${Displays.rotationLabels[root.turn]} — click to turn, right-click to reset`, root);
            else
                root.tooltip?.hide(root);
        }
    }

    FIcon {
        anchors.centerIn: parent
        icon: "rotate_right"
        // Tinted whenever the panel is not the way round it was built, so a
        // screen left in portrait is visibly a state and not just how things
        // are now — and the glyph itself turns with the screen, so the button
        // reads as "which way round am I" without a tooltip.
        rotation: root.turn * 90
        color: root.turn === 0 ? Theme.barFg : Theme.accent
        font.pixelSize: Appearance.sizes.glyph

        Behavior on rotation {
            Anim {
                duration: Appearance.anim.durations.expressiveDefaultSpatial
                curve: Appearance.anim.curves.expressiveDefaultSpatial
            }
        }
        opacity: Appearance.touch ? 1 : 0
        scale: Appearance.touch ? 1 : 0.55

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
