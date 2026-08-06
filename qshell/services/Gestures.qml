pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Touchscreen edge swipes, as intentions rather than as calls.
//
// Hyprland's gesture system is trackpad-only — `hl.gesture(…)` builds
// CTrackpadGesture objects, and the directions it accepts are
// horizontal/vertical/swipe/pinch with no notion of an edge — so the three
// swipes a tablet actually wants have to be caught by the shell. The strips
// that catch them are modules/gestures/EdgeSwipes.qml; this is where they
// arrive, and what the panels listen to.
//
// A signal hub rather than direct calls, for the reason services/Search.qml
// already gives for requestMode(): the gesture strips and the panels both
// import services, and neither should have to reach into the other's tree
// (which for the Control Center means reaching into a per-monitor Variants
// delegate, from a different window, and picking the right one).
Singleton {
    id: root

    // How far a finger has to travel from the edge before it counts, in the
    // shell's logical pixels. Small enough to feel like a flick, large enough
    // that resting a thumb on the bezel while holding the tablet doesn't open
    // the launcher every time you shift your grip.
    readonly property int threshold: 55

    // The strips are this thick. Wider than a hairline because a finger is not
    // a mouse; narrow enough that the window underneath keeps almost all of
    // its edge for `resize_on_border`, which claims 20px either side of the
    // frame (config/hypr/lua/options.lua).
    readonly property int stripWidth: 8

    readonly property bool enabled: Settings.edgeSwipes && Appearance.touch

    signal launcherRequested
    signal overviewRequested
    signal controlRequested
}
