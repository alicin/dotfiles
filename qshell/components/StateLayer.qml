import QtQuick
import Quickshell.Widgets
import qs.config

// Hover/press feedback in the caelestia style: an 8% hover wash plus a ripple
// that expands from the press point, clipped to the pill radius. It is a
// MouseArea — place it under the content and use onClicked/acceptedButtons
// as usual.
MouseArea {
    id: root

    property color color: Theme.barFg
    property real radius: Appearance.rounding.normal
    property real hoverOpacity: 0.08
    property real rippleOpacity: 0.12
    // Extends the hit area this far above and below the visual pill (the wash
    // and ripple stay put). Bar modules pass barSlop so the strip of pixels
    // against the screen edge takes the click too.
    property real hitSlop: 0

    readonly property real maxRippleRadius: Math.sqrt(width * width + height * height)

    anchors.fill: parent
    anchors.topMargin: -hitSlop
    anchors.bottomMargin: -hitSlop
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onPressed: mouse => {
        ripple.cx = mouse.x;
        ripple.cy = mouse.y - root.hitSlop;
        rippleAnim.restart();
    }

    ClippingRectangle {
        anchors.fill: parent
        anchors.topMargin: root.hitSlop
        anchors.bottomMargin: root.hitSlop
        radius: root.radius
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: root.color
            opacity: root.containsMouse ? root.hoverOpacity : 0

            Behavior on opacity {
                Anim {
                    curve: Appearance.anim.curves.expressiveDefaultEffects
                    duration: Appearance.anim.durations.expressiveDefaultEffects
                }
            }
        }

        Rectangle {
            id: ripple

            property real cx
            property real cy
            property real r: 0

            x: cx - r
            y: cy - r
            width: r * 2
            height: r * 2
            radius: r
            color: root.color
            opacity: 0
        }
    }

    SequentialAnimation {
        id: rippleAnim

        PropertyAction {
            target: ripple
            property: "opacity"
            value: root.rippleOpacity
        }

        Anim {
            target: ripple
            property: "r"
            from: 0
            to: root.maxRippleRadius
            duration: Appearance.anim.durations.expressiveSlowEffects * 2
        }

        Anim {
            target: ripple
            property: "opacity"
            to: 0
            curve: Appearance.anim.curves.expressiveSlowEffects
            duration: Appearance.anim.durations.expressiveSlowEffects
        }
    }
}
