import QtQuick
import qs.config

// Wheel input normalized to mouse-notch units, for bar gestures that act on
// scroll rather than scrolling a list (WheelScroll is the list one).
//
// A mouse notch arrives as one ±120 angleDelta event; a touchpad flick is a
// stream of tiny pixelDelta events. The old handlers acted once per *event*,
// so the same flick that moved a mouse one workspace threw a touchpad across
// several. This accumulates into notches and exposes both readings:
//
//   stepped(steps)  — whole notches, for discrete jumps (workspaces)
//   moved(notches)  — fractional, for smooth values (volume)
//
// Usage:  WheelDetent { onStepped: steps => ... }
WheelHandler {
    id: root

    signal stepped(int steps)
    signal moved(real notches)

    // Touchpad travel that equals one notch. pixelDelta arrives pre-scaled by
    // hyprland's touchpad scroll_factor (0.3), ~2-6px per event; a deliberate
    // flick sums to roughly one of these.
    property real pxPerNotch: 90

    property real acc: 0

    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

    onWheel: event => {
        const px = event.pixelDelta.y;
        const ang = event.angleDelta.y;

        // Fingers lifting is a zero-delta event; consume it and nothing else.
        if (px === 0 && ang === 0) {
            event.accepted = true;
            return;
        }

        // Touchpads send high-resolution pixelDelta, mice send angleDelta in
        // eighths of a degree — same split WheelScroll relies on.
        const notches = px !== 0 ? px / root.pxPerNotch : ang / 120;

        // Reversing direction starts a fresh gesture; leftover momentum from
        // the old one shouldn't mute the first movement of the new one.
        if (root.acc !== 0 && (notches > 0) !== (root.acc > 0))
            root.acc = 0;

        root.moved(notches);

        root.acc += notches;
        const whole = Math.trunc(root.acc);
        if (whole !== 0) {
            root.acc -= whole;
            root.stepped(whole);
        }

        idle.restart();
        event.accepted = true;
    }

    // A stale partial notch shouldn't carry into a flick made seconds later.
    // Declared as a property because a pointer handler has no default property
    // to parent children into.
    readonly property Timer idle: Timer {
        interval: 400
        onTriggered: root.acc = 0
    }
}
