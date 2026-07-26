import QtQuick
import qs.config
import qs.components
import qs.services

// Privacy lights, macOS-style: a glyph appears only while something is actually
// using the camera or the microphone, immediately left of the tray ellipsis.
//
// Presence *is* the signal, which is why neither of these has an idle state.
// The mic keys off active capture rather than the mute switch — an unmuted mic
// with nothing listening isn't a privacy event, and an indicator lit all day is
// one you stop seeing. A muted mic shows nothing at all: if nothing can hear
// you, there's nothing to warn about.
//
// Both fade and scale in, because appearing out of nowhere in the corner of a
// bar is easy to miss, and a moving thing isn't.
Row {
    id: root

    spacing: Appearance.s(2)

    component Light: Item {
        id: light

        property bool active: false
        property string glyph: ""
        property color tint: Theme.barFg

        signal tapped

        // Collapses to nothing when inactive, so the rest of the bar doesn't
        // shuffle around it.
        implicitWidth: active ? inner.implicitWidth + Appearance.sizes.modulePad : 0
        implicitHeight: Appearance.sizes.barInner
        visible: implicitWidth > 0.5

        Behavior on implicitWidth {
            Anim {
                duration: Appearance.anim.durations.expressiveFastSpatial
                curve: Appearance.anim.curves.emphasized
            }
        }

        StateLayer {
            onClicked: light.tapped()
        }

        FIcon {
            id: inner

            anchors.centerIn: parent
            icon: light.glyph
            color: light.tint
            opacity: light.active ? 1 : 0
            scale: light.active ? 1 : 0.6

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

    // Green because that's the colour everyone already reads as "the camera is
    // live", from every other laptop and phone they've used.
    Light {
        active: Camera.inUse
        glyph: "videocam_fill"
        tint: Theme.barOk
    }

    // Click mutes — the one useful thing to do about a mic you didn't expect to
    // be live, and it makes this disappear.
    Light {
        active: Audio.micInUse && !Audio.micMuted
        glyph: "mic_fill"
        tint: Theme.barWarn
        onTapped: {
            Audio.toggleMicMute();
            Osd.show("mic");
        }
    }
}
