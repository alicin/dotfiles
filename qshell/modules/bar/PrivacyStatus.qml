import QtQuick
import qs.config
import qs.components
import qs.services

// Privacy lights, immediately left of the tray ellipsis. Presence is the
// signal, so neither has an idle state:
//
//   amber mic    — the mic is live, i.e. not muted. Anything *could* be
//                  listening, which is the question this answers; whether
//                  something currently is doesn't change the exposure.
//   green camera — a webcam is open right now.
//
// Filled squircles rather than bare glyphs: a coloured icon on a transparent
// bar over an arbitrary wallpaper is at the mercy of whatever's behind it,
// while a solid badge carries its own contrast and reads as a status light
// instead of one more clickable icon.
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
        property color bg: Theme.barFg

        signal tapped

        // Collapses to nothing when inactive, so the rest of the bar doesn't
        // shuffle around it.
        implicitWidth: active ? badge.width + Appearance.s(6) : 0
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

        Rectangle {
            id: badge

            anchors.centerIn: parent
            // Same height as the active workspace pill, so the two ends of the
            // bar agree on how big a "container" is.
            width: Appearance.sizes.barInner
            height: width
            // A true squircle is a superellipse and would need a Shape; 0.38 of
            // the side is what the empty-workspace squircle already uses and
            // reads the same at this size.
            radius: width * 0.38
            color: light.bg

            opacity: light.active ? 1 : 0
            scale: light.active ? 1 : 0.55

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

            FIcon {
                anchors.centerIn: parent
                icon: light.glyph
                font.pixelSize: Appearance.s(15)
                color: "#ffffff"
            }
        }
    }

    // Green because that's the colour everyone already reads as "the camera is
    // live", from every other laptop and phone they've used.
    Light {
        active: Camera.inUse
        glyph: "videocam_fill"
        bg: Theme.privacyCam
    }

    // Click mutes, which also makes this disappear — so the light is both the
    // warning and the switch that clears it.
    Light {
        active: !Audio.micMuted
        glyph: "mic_fill"
        bg: Theme.privacyMic
        onTapped: {
            Audio.toggleMicMute();
            Osd.show("mic");
        }
    }
}
