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
// Three shapes, chosen by what the value actually is:
//   bar    — volume, display brightness: continuous
//   steps  — keyboard backlight: the ROG light has three steps and nothing in
//            between, and a continuous fill would promise a precision the
//            hardware doesn't have
//   label  — mic mute, power profile: a state, not a level, so a bar sitting at
//            some arbitrary fill would be actively misleading
Scope {
    id: root

    readonly property bool shown: Osd.kind !== ""

    // Pinned per showing (the assignment severs the window's live screen
    // binding on first use, on purpose) — the pill used to jump screens
    // mid-fade when the cursor crossed monitors.
    onShownChanged: {
        if (shown)
            win.screen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null;
    }

    readonly property string mode: {
        if (Osd.kind === "kbd")
            return "steps";
        if (Osd.kind === "mic" || Osd.kind === "power" || Osd.kind === "countdown" || Osd.kind === "submap")
            return "label";
        return "bar";
    }

    readonly property bool muted: (Osd.kind === "volume" && Audio.muted) || (Osd.kind === "mic" && Audio.micMuted)

    readonly property real value: Osd.kind === "brightness" ? Brightness.display : Audio.volume

    // Which sink the volume is actually driving — with BT headphones and
    // speakers both present, a bare bar doesn't say what just changed.
    readonly property string device: Osd.kind === "volume" ? (Audio.sink?.description ?? "") : ""

    readonly property string label: {
        if (Osd.kind === "mic")
            return Audio.micMuted ? "Microphone muted" : "Microphone on";
        if (Osd.kind === "countdown")
            return `Screenshot in ${Capture.countdown}…`;
        if (Osd.kind === "submap")
            return Osd.submapLabel;
        return Power.label(Power.profile);
    }

    readonly property string glyph: {
        if (Osd.kind === "brightness")
            return Brightness.display < 0.4 ? "sun_min_fill" : "sun_max_fill";
        if (Osd.kind === "kbd")
            return "keyboard";
        if (Osd.kind === "mic")
            return Audio.micMuted ? "mic_slash_fill" : "mic_fill";
        if (Osd.kind === "power")
            return Power.glyph(Power.profile);
        if (Osd.kind === "countdown")
            return "timer_fill";
        if (Osd.kind === "submap")
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

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Appearance.s(64) - (1 - anim) * Appearance.s(16)

            // Label mode shrinks to its text — a 320px pill with "Microphone
            // muted" adrift in it reads as a layout bug. Animated, so switching
            // kinds while one is already up morphs instead of snapping.
            width: root.mode === "label" ? Math.max(Appearance.s(190), Appearance.s(78) + label.implicitWidth) : Appearance.s(320)
            // A touch taller for volume, to carry the device line.
            height: root.device !== "" ? Appearance.s(72) : Appearance.s(58)

            Behavior on height {
                Anim {
                    duration: Appearance.anim.durations.expressiveFastSpatial
                    curve: Appearance.anim.curves.emphasized
                }
            }
            radius: height / 2
            color: Theme.surfaceBg
            border.width: 1
            border.color: Theme.surfaceBorder

            Behavior on width {
                Anim {
                    duration: Appearance.anim.durations.expressiveFastSpatial
                    curve: Appearance.anim.curves.emphasized
                }
            }

            visible: anim > 0.005
            // Faster than the scale so it's legible before it has finished
            // settling.
            opacity: Math.min(1, anim * 1.6)
            scale: 0.86 + 0.14 * anim

            // Decelerating, never overshooting: the M3 *Spatial curves all rise
            // past 1 before settling, which is the bounce. Out stays a plain
            // accelerate.
            Behavior on anim {
                Anim {
                    duration: root.shown ? Appearance.anim.durations.expressiveFastSpatial : Appearance.anim.durations.expressiveDefaultEffects
                    curve: root.shown ? Appearance.anim.curves.emphasizedDecel : Appearance.anim.curves.standardAccel
                }
            }

            Item {
                id: glyphSlot

                x: Appearance.s(18)
                width: Appearance.s(26)
                height: Appearance.s(58)

                FIcon {
                    anchors.centerIn: parent
                    icon: root.glyph
                    font.pixelSize: Appearance.s(20)
                    color: root.muted ? Theme.surfaceFgDim : Theme.surfaceFg
                }
            }

            StyledText {
                visible: root.device !== ""
                anchors.left: glyphSlot.right
                anchors.leftMargin: Appearance.s(14)
                anchors.right: parent.right
                anchors.rightMargin: Appearance.s(20)
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Appearance.s(9)
                text: root.device
                color: Theme.surfaceFgDim
                font.pixelSize: Appearance.font.size.small
                font.weight: Font.Normal
                elide: Text.ElideRight
            }

            // ── Continuous: volume, display brightness ──
            ClippingRectangle {
                id: bar

                anchors.left: glyphSlot.right
                anchors.leftMargin: Appearance.s(14)
                anchors.right: pct.left
                anchors.rightMargin: Appearance.s(12)
                anchors.verticalCenter: glyphSlot.verticalCenter
                height: Appearance.s(8)
                radius: height / 2
                color: Qt.alpha(Theme.surfaceFg, 0.16)
                visible: root.mode === "bar"

                // Clipped anyway: the fill's rounded ends would otherwise show
                // through the square corners of the track.
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
                            curve: Appearance.anim.curves.emphasizedDecel
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
                anchors.verticalCenter: glyphSlot.verticalCenter
                width: Appearance.s(44)
                horizontalAlignment: Text.AlignRight
                visible: root.mode === "bar"
                text: `${Math.round(root.value * 100)}%`
                color: Theme.surfaceFgDim
                font.pixelSize: Appearance.font.size.small
            }

            // ── State, not a level: mic mute, power profile ──
            StyledText {
                id: label

                anchors.left: glyphSlot.right
                anchors.leftMargin: Appearance.s(14)
                anchors.verticalCenter: glyphSlot.verticalCenter
                visible: root.mode === "label"
                text: root.label
                color: Theme.surfaceFg
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
                anchors.verticalCenter: glyphSlot.verticalCenter
                height: Appearance.s(11)
                visible: root.mode === "steps"

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
                                    curve: Appearance.anim.curves.emphasizedDecel
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
