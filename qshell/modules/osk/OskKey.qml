import QtQuick
import qs.config
import qs.components
import qs.services

// One key cap.
//
// Input is a TapHandler rather than the shell's usual StateLayer, for two
// reasons that are specific to a keyboard:
//
//   • Multi-touch. Qt synthesises mouse events from a single touch point, so a
//     grid of MouseAreas can only ever have one key down at a time — which
//     turns Shift+letter, or simply typing faster than you lift, into dropped
//     characters. Pointer handlers get the real touch points and several keys
//     can be pressed at once.
//   • Fire on press. Every physical and on-screen keyboard repeats and reports
//     on the way down; waiting for the release (what onClicked does) reads as
//     lag on a surface you are tapping thirty times a sentence.
Rectangle {
    id: root

    // The raw entry from the layout — a bare string for a character key, an
    // object for everything else. Normalised through Osk.spec().
    required property var key

    readonly property var spec: Osk.spec(root.key)
    readonly property bool isMod: ["shift", "ctrl", "alt", "logo"].includes(root.spec.a)
    // A modifier armed for the next key, vs one locked until tapped off. Both
    // are drawn, differently: armed is a tint, locked is the filled accent,
    // because "this will apply once" and "this will apply until you say
    // otherwise" are worth being able to tell apart at a glance.
    readonly property bool armed: root.isMod && Osk[root.spec.a] === true
    readonly property bool locked: root.isMod && Osk[root.spec.a + "Lock"] === true

    // Modifiers, Return, Backspace and the layer switch read as slightly
    // recessed, the way they do on a real keyboard.
    //
    // The space bar is deliberately NOT one of them, even though it types a
    // character nobody can see. At the recessed tint it was indistinguishable
    // from the panel behind it — same RGB to the pixel — which made the most
    // frequently hit key on the keyboard the only one with no visible edges.
    readonly property bool special: root.spec.t === undefined

    radius: Appearance.sizes.oskRadius
    color: {
        if (root.locked)
            return Theme.accent;
        if (tap.pressed)
            return Qt.alpha(Theme.surfaceFg, 0.28);
        if (root.armed)
            return Qt.alpha(Theme.accent, 0.35);
        return Qt.alpha(Theme.surfaceFg, root.special ? 0.07 : 0.13);
    }

    // The one physical cue a glass key can give: it dips under the finger.
    // Colour alone reads fine at a glance but is invisible *under* the finger
    // that is pressing it, which is exactly where you are looking.
    scale: tap.pressed ? 0.93 : 1

    Behavior on scale {
        Anim {
            duration: Appearance.anim.durations.expressiveFastEffects
        }
    }

    Behavior on color {
        CAnim {}
    }

    TapHandler {
        id: tap

        // Held down counts, not just tapped: a key that repeats has to keep
        // reporting for as long as the finger is on it, and DragThreshold
        // would cancel the moment the finger rolled a pixel.
        gesturePolicy: TapHandler.ReleaseWithinBounds

        onPressedChanged: {
            if (tap.pressed) {
                Osk.send(root.key);
                if (root.spec.r === true)
                    repeatDelay.start();
            } else {
                repeatDelay.stop();
                repeatRun.stop();
            }
        }
    }

    // The usual two-stage repeat: a pause long enough that holding a key to
    // look at it doesn't fire, then a rate fast enough to delete a word.
    Timer {
        id: repeatDelay

        interval: 400
        onTriggered: repeatRun.start()
    }

    Timer {
        id: repeatRun

        interval: 45
        repeat: true
        onTriggered: Osk.send(root.key)
    }

    FIcon {
        anchors.centerIn: parent
        visible: root.spec.g !== undefined
        // Shift swaps to its filled form while it will apply — the same signal
        // every phone keyboard uses, readable from the key itself without
        // checking the letter caps.
        icon: root.spec.a === "shift" && (root.armed || root.locked) ? "shift_fill" : (root.spec.g ?? "")
        color: root.locked ? Theme.accentFg : Theme.surfaceFg
        font.pixelSize: Math.min(Appearance.s(19), root.height * 0.42)
    }

    StyledText {
        anchors.centerIn: parent
        visible: root.spec.g === undefined
        text: Osk.labelOf(root.key)
        color: root.locked ? Theme.accentFg : Theme.surfaceFg
        // Multi-character caps (tab, home, pgup) shrink so they don't crowd
        // the cap; a single character gets the full size.
        font.pixelSize: text.length > 1 ? Math.min(Appearance.font.size.small, root.height * 0.3) : Math.min(Appearance.s(20), root.height * 0.44)
        font.weight: root.special ? Font.Normal : Font.Medium
    }
}
