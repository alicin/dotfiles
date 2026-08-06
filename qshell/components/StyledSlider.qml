import QtQuick
import qs.config

// Horizontal slider for the audio menu. Renders `value` (0..1), emits
// moved(v) on drag/wheel — the caller writes the backend, the binding
// feeds the rendered value back.
Item {
    id: root

    property real value: 0

    signal moved(real value)

    readonly property real knob: Appearance.s(13)
    readonly property bool dragging: area.pressed

    // Animate the *value*, never the geometry. Putting the Behavior on the
    // fill's width instead made it re-fire on layout: a menu's slider is built
    // at parent.width 0, so opening the menu played a fill-sweep every time.
    property real shown: value

    Behavior on shown {
        enabled: !root.dragging

        Anim {
            duration: Appearance.anim.durations.small
        }
    }

    implicitHeight: Appearance.s(22)

    function valueAt(x: real): real {
        return Math.max(0, Math.min(1, (x - knob / 2) / (width - knob)));
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Appearance.s(5)
        radius: height / 2
        color: Qt.alpha(Theme.surfaceFg, 0.16)
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: root.knob / 2 + root.shown * (parent.width - root.knob)
        height: Appearance.s(5)
        radius: height / 2
        color: Theme.accent
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: root.shown * (parent.width - root.knob)
        width: root.knob
        height: root.knob
        radius: root.knob / 2
        color: Theme.accent
    }

    MouseArea {
        id: area

        anchors.fill: parent
        // Vertical slop up to the touch floor: the visual is a 5px track with
        // a 15px knob, and a fingertip cannot land on that. Zero with a
        // pointer (touchTarget is 0 outside touch mode).
        anchors.topMargin: -Math.max(0, (Appearance.touchTarget - root.height) / 2)
        anchors.bottomMargin: -Math.max(0, (Appearance.touchTarget - root.height) / 2)
        // A finger dragging horizontally always wobbles a few px vertically,
        // and inside the popout's (vertical) Flickable that wobble crossed the
        // drag threshold and handed the grab to the list: the slider froze
        // mid-drag and the page scrolled instead — with the value committed
        // wherever the steal happened, which for the scale sliders means the
        // whole shell resized to an accident. The drag belongs to the slider
        // until the finger lifts.
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.moved(root.valueAt(mouse.x))
        onPositionChanged: mouse => {
            if (pressed)
                root.moved(root.valueAt(mouse.x));
        }
    }

    WheelHandler {
        onWheel: event => root.moved(Math.max(0, Math.min(1, root.value + (event.angleDelta.y > 0 ? 0.04 : -0.04))))
    }
}
