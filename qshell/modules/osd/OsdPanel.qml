import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// Volume / brightness / keyboard-backlight OSD: a pill near the bottom of the
// focused screen that springs in on a media key and fades out on its own.
//
// Entirely click-through (empty input mask) — this is feedback, not a control,
// and it appears exactly where you might be aiming at something else.
//
// Keyboard backlight gets *segments* rather than a bar: the ROG light has three
// steps and nothing in between, so a continuous fill would promise a precision
// the hardware doesn't have.
Scope {
    id: root

    readonly property bool shown: Osd.kind !== ""
    readonly property bool isKbd: Osd.kind === "kbd"
    readonly property bool muted: Osd.kind === "volume" && Audio.muted

    readonly property real value: Osd.kind === "brightness" ? Brightness.display : Audio.volume

    readonly property string glyph: {
        if (Osd.kind === "brightness")
            return Brightness.display < 0.4 ? "sun_min_fill" : "sun_max_fill";
        if (Osd.kind === "kbd")
            return "keyboard";
        if (Audio.muted)
            return "speaker_slash_fill";
        if (Audio.volume < 0.01)
            return "speaker_fill";
        return Audio.volume < 0.34 ? "speaker_1_fill" : Audio.volume < 0.67 ? "speaker_2_fill" : "speaker_3_fill";
    }

    PanelWindow {
        id: win

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null
        color: "transparent"
        implicitWidth: Appearance.s(420)
        implicitHeight: Appearance.s(170)

        anchors {
            bottom: true
        }

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        WlrLayershell.namespace: "qshell:osd"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // No input region at all: pointer events pass straight through.
        mask: Region {}

        Elevation {
            anchors.fill: pill
            radius: pill.radius
            level: 3
            visible: pill.visible
            opacity: pill.opacity
            scale: pill.scale
        }

        Rectangle {
            id: pill

            // 0 hidden, 1 shown — drives opacity, scale and the rise together
            // so they can't drift apart.
            property real anim: root.shown ? 1 : 0
            // 0..1..0 on every keypress.
            property real punch: 0

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Appearance.s(64) - (1 - anim) * Appearance.s(16)

            width: Appearance.s(320)
            height: Appearance.s(58)
            radius: height / 2
            color: Theme.surfaceBg
            border.width: 1
            border.color: Theme.surfaceBorder

            visible: anim > 0.005
            // Faster than the scale so it's legible before it's finished
            // settling, rather than fading in behind its own overshoot.
            opacity: Math.min(1, anim * 1.6)
            scale: (0.86 + 0.14 * anim) * (1 + 0.05 * punch)

            // In on the expressive spatial curve, which overshoots — that
            // slight rubberiness is most of what makes this feel alive. Out is
            // deliberately not springy: a bounce on the way out reads as a
            // glitch, not a flourish.
            Behavior on anim {
                Anim {
                    duration: root.shown ? Appearance.anim.durations.expressiveFastSpatial : Appearance.anim.durations.expressiveDefaultEffects
                    curve: root.shown ? Appearance.anim.curves.expressiveDefaultSpatial : Appearance.anim.curves.standardAccel
                }
            }

            Connections {
                target: Osd

                function onPulseChanged(): void {
                    punchAnim.restart();
                }
            }

            SequentialAnimation {
                id: punchAnim

                Anim {
                    target: pill
                    property: "punch"
                    to: 1
                    duration: Appearance.anim.durations.expressiveFastEffects * 0.6
                    curve: Appearance.anim.curves.standardDecel
                }

                Anim {
                    target: pill
                    property: "punch"
                    to: 0
                    duration: Appearance.anim.durations.expressiveFastSpatial
                    curve: Appearance.anim.curves.expressiveFastSpatial
                }
            }

            Item {
                id: glyphSlot

                x: Appearance.s(18)
                width: Appearance.s(26)
                height: parent.height

                FIcon {
                    anchors.centerIn: parent
                    icon: root.glyph
                    font.pixelSize: Appearance.s(20)
                    color: root.muted ? Theme.surfaceFgDim : Theme.surfaceFg
                }
            }

            // ── Continuous: volume, display brightness ──
            ClippingRectangle {
                id: bar

                anchors.left: glyphSlot.right
                anchors.leftMargin: Appearance.s(14)
                anchors.right: pct.left
                anchors.rightMargin: Appearance.s(12)
                anchors.verticalCenter: parent.verticalCenter
                height: Appearance.s(8)
                radius: height / 2
                color: Qt.alpha(Theme.surfaceFg, 0.16)
                visible: !root.isKbd

                // Clipped, because the fill's curve overshoots its target and
                // would otherwise poke out past the rounded end of the track.
                Rectangle {
                    // Floor at a circle so 0% still reads as a control at rest
                    // rather than a missing element.
                    width: Math.max(parent.height, parent.width * root.value)
                    height: parent.height
                    radius: height / 2
                    color: root.muted ? Qt.alpha(Theme.surfaceFg, 0.35) : Theme.accent

                    Behavior on width {
                        Anim {
                            duration: Appearance.anim.durations.expressiveFastSpatial
                            curve: Appearance.anim.curves.expressiveDefaultSpatial
                        }
                    }

                    Behavior on color {
                        CAnim {}
                    }
                }
            }

            StyledText {
                id: pct

                anchors.right: parent.right
                anchors.rightMargin: Appearance.s(20)
                anchors.verticalCenter: parent.verticalCenter
                width: Appearance.s(44)
                horizontalAlignment: Text.AlignRight
                visible: !root.isKbd
                text: `${Math.round(root.value * 100)}%`
                color: Theme.surfaceFgDim
                font.pixelSize: Appearance.font.size.small
            }

            // ── Stepped: keyboard backlight ──
            Item {
                id: steps

                readonly property int gap: Appearance.s(6)
                readonly property real cell: (width - (Brightness.kbdMax - 1) * gap) / Math.max(1, Brightness.kbdMax)

                anchors.left: glyphSlot.right
                anchors.leftMargin: Appearance.s(14)
                anchors.right: parent.right
                anchors.rightMargin: Appearance.s(20)
                anchors.verticalCenter: parent.verticalCenter
                height: Appearance.s(11)
                visible: root.isKbd

                Row {
                    anchors.fill: parent
                    spacing: steps.gap

                    Repeater {
                        model: Brightness.kbdMax

                        Rectangle {
                            required property int index

                            readonly property bool lit: index < Brightness.kbd

                            width: steps.cell
                            height: parent.height
                            radius: height / 2
                            color: lit ? Theme.accent : Qt.alpha(Theme.surfaceFg, 0.16)
                            // Unlit segments sit a touch small, so the one that
                            // just came on visibly pops to full size.
                            scale: lit ? 1 : 0.82

                            Behavior on color {
                                CAnim {}
                            }

                            Behavior on scale {
                                Anim {
                                    duration: Appearance.anim.durations.expressiveFastSpatial
                                    curve: Appearance.anim.curves.expressiveFastSpatial
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
