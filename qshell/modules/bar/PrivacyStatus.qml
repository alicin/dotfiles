import QtQuick
import qs.config
import qs.components
import qs.services

// Privacy lights, immediately left of the tray ellipsis. Presence is the
// signal, so neither has an idle state:
//
//   amber mic    — an app is capturing the mic *right now* (live PipeWire
//                  links) and the mic isn't muted. Not "unmuted": that's the
//                  default all day, and a light that's always on is one you
//                  stop seeing. This one appearing means audio is flowing to
//                  someone.
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
        // Who's responsible — hovering expands the pill to name the apps,
        // tray-reveal style, since a 34px bar window has no room to hang a
        // tooltip below itself.
        property string detail: ""
        // Only a light with a job gets the pointer cursor and ripple — the
        // camera one used to ripple and then do nothing, which reads as a
        // broken control rather than a status light.
        property bool tappable: false

        readonly property bool showDetail: hover.hovered && detail !== ""

        signal tapped

        // Collapses to nothing when inactive, so the rest of the bar doesn't
        // shuffle around it. This is the ONE animation authority for width —
        // the badge follows it un-animated; two chained Behaviors let the
        // badge outrun its container and paint over the neighbors.
        implicitWidth: active ? (showDetail ? inner.implicitWidth + Appearance.s(14) : Appearance.sizes.barInner) + Appearance.s(6) : 0
        implicitHeight: Appearance.sizes.barInner
        visible: implicitWidth > 0.5

        Behavior on implicitWidth {
            Anim {
                duration: Appearance.anim.durations.expressiveFastSpatial
                curve: Appearance.anim.curves.emphasized
            }
        }

        HoverHandler {
            id: hover

            margin: Appearance.sizes.barSlop
        }

        StateLayer {
            visible: light.tappable
            hitSlop: Appearance.sizes.barSlop
            onClicked: light.tapped()
        }

        Rectangle {
            id: badge

            anchors.centerIn: parent
            // Same height as the active workspace pill, so the two ends of the
            // bar agree on how big a "container" is. Tracks the Light's
            // animated width (clamped: implicitWidth animates through 0 on
            // deactivate); clipped so the hover text is revealed by the
            // pill's edge rather than popping in beside it.
            width: Math.max(0, light.width - Appearance.s(6))
            height: Appearance.sizes.barInner
            clip: true
            // A true squircle is a superellipse and would need a Shape; 0.38 of
            // the side is what the empty-workspace squircle already uses and
            // reads the same at this size.
            radius: height * 0.38
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

            Row {
                id: inner

                anchors.centerIn: parent
                spacing: Appearance.s(5)

                FIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: light.glyph
                    font.pixelSize: Appearance.s(15)
                    color: "#ffffff"
                }

                StyledText {
                    visible: light.showDetail
                    anchors.verticalCenter: parent.verticalCenter
                    text: light.detail
                    color: "#ffffff"
                    font.pixelSize: Appearance.font.size.small
                    font.weight: Font.Bold
                }
            }
        }
    }

    // Green because that's the colour everyone already reads as "the camera is
    // live", from every other laptop and phone they've used.
    Light {
        active: Camera.inUse
        glyph: "videocam_fill"
        bg: Theme.privacyCam
        detail: Camera.apps.join(", ")
    }

    // Click mutes, which also makes this disappear — so the light is both the
    // warning and the switch that clears it. (The capture links usually
    // outlive the mute — apps hold them and receive silence — hence the
    // muted-check rather than trusting micInUse alone.)
    Light {
        active: Audio.micInUse && !Audio.micMuted
        glyph: "mic_fill"
        bg: Theme.privacyMic
        detail: Audio.micUsers.join(", ")
        tappable: true
        onTapped: {
            Audio.toggleMicMute();
            Osd.show("mic");
        }
    }
}
