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

    // What the pill is drawing right now: a transient value wins for its
    // 1.5s, then the sustained submap legend (if any) takes the spot back.
    // Deriving this here — instead of stuffing "submap" into Osd.kind — is
    // what stopped the volume/submap flicker: Pipewire bursts and submap
    // events no longer overwrite each other's state.
    readonly property string showing: Osd.kind !== "" ? Osd.kind : (Osd.submap !== "" ? "submap" : "")

    readonly property bool shown: root.showing !== ""

    // What the pill actually DRAWS, which is not the same question as whether
    // it is up. `showing` drops to "" the instant the OSD is dismissed, but the
    // pill stays on screen for the fade-out — and every content property below
    // keys off it, so at that moment `mode` fell through to "bar", `glyph` to
    // the speaker fallback and `width` to s(320). The submap legend visibly
    // collapsed into a volume pill, complete with bar and percentage, and THEN
    // faded. Latching the last real value lets the fade finish drawing what was
    // there. Worst on the submap because its pill is the widest (~544px vs
    // 320px), but mic / power / countdown were all doing it to a smaller degree.
    property string drawing: ""

    onShowingChanged: {
        if (root.showing !== "")
            root.drawing = root.showing;
    }

    // Pinned per showing — the pill used to jump screens mid-fade when the
    // cursor crossed monitors. By NAME: a ShellScreen object dies with its
    // monitor and a severed binding never recovers (see the launcher's pin).
    property string pinned: ""

    onShownChanged: {
        if (shown)
            root.pinned = Hyprland.focusedMonitor?.name ?? "";
    }

    readonly property string mode: {
        if (root.drawing === "kbd")
            return "steps";
        if (root.drawing === "mic" || root.drawing === "power" || root.drawing === "countdown" || root.drawing === "submap")
            return "label";
        return "bar";
    }

    readonly property bool muted: (root.drawing === "volume" && Audio.muted) || (root.drawing === "mic" && Audio.micMuted)

    readonly property real value: root.drawing === "brightness" ? Brightness.display : Audio.volume

    // Which sink the volume is actually driving — with BT headphones and
    // speakers both present, a bare bar doesn't say what just changed.
    readonly property string device: root.drawing === "volume" ? (Audio.sink?.description ?? "") : ""

    readonly property string label: {
        if (root.drawing === "mic")
            return Audio.micMuted ? "Microphone muted" : "Microphone on";
        if (root.drawing === "countdown")
            return `Screenshot in ${Capture.countdown}…`;
        if (root.drawing === "submap")
            return Osd.submapLabel;
        return Power.label(Power.profile);
    }

    readonly property string glyph: {
        if (root.drawing === "brightness")
            return Brightness.display < 0.4 ? "sun_min_fill" : "sun_max_fill";
        if (root.drawing === "kbd")
            return "keyboard";
        if (root.drawing === "mic")
            return Audio.micMuted ? "mic_slash_fill" : "mic_fill";
        if (root.drawing === "power")
            return Power.glyph(Power.profile);
        if (root.drawing === "countdown")
            return "timer_fill";
        if (root.drawing === "submap")
            return "keyboard";
        if (Audio.muted)
            return "speaker_slash_fill";
        if (Audio.volume < 0.01)
            return "speaker_fill";
        return Audio.volume < 0.34 ? "speaker_1_fill" : Audio.volume < 0.67 ? "speaker_2_fill" : "speaker_3_fill";
    }

    PanelWindow {
        id: win

        readonly property var realScreen: Displays.screenFor(root.pinned)

        // Held in a property, never read back off `screen` (that would be a
        // binding loop), and gating `visible` so the surface is rebuilt when an
        // output comes back — Displays.screenFor has the whole story.
        screen: win.realScreen
        visible: win.realScreen !== null
        color: "transparent"
        implicitHeight: Appearance.s(170)

        // Full width, and therefore CONSTANT — the surface never resizes.
        //
        // This used to be `implicitWidth: max(s(420), pill.width + s(48))`, i.e.
        // derived from a value with a 350ms Behavior on it, so the layer surface
        // was resized on every frame of the pill's morph. rules.lua animates
        // every `qshell:.*` surface change, so Hyprland ran a second, laggier
        // fade underneath the real one and the whole thing read as choppy and
        // slow. Exactly the trap the bar popouts hit and fixed by making their
        // host window a constant (see README).
        //
        // Anchoring both edges rather than picking a number sidesteps the
        // logical-vs-physical pixel question entirely, and costs nothing: the
        // input mask below is empty, so the surface is wholly click-through.
        // It also retires the old clipping bug — the ~544px submap legends can
        // no longer be cut off by a 420px surface, since the pill clamps itself
        // to maxWidth and centres in the full width.
        anchors {
            bottom: true
            left: true
            right: true
        }

        // Above the on-screen keyboard rather than behind it: a volume pill
        // drawn under the space bar is a pill nobody sees. Same reasoning as
        // the launcher and the clipboard picker — see ClipboardHistory.qml.
        margins {
            bottom: Osk.active && Osk.reservedScreen === (win.screen?.name ?? "") ? Osk.reservedPx : 0
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

            // Ceiling on how far label mode may grow. A hint wider than the
            // screen is a config mistake, but it has to degrade to elided text
            // rather than to text drawn past the edge of the surface, which is
            // just missing. Leaves a margin so the pill never touches the sides.
            // Measured off the surface now that it spans the output, rather than
            // off screen.width — same number, but in the units the pill is
            // actually laid out in.
            readonly property int maxWidth: Math.max(Appearance.s(320), win.width - Appearance.s(96))

            // Label mode shrinks to its text — a 320px pill with "Microphone
            // muted" adrift in it reads as a layout bug. Animated, so switching
            // kinds while one is already up morphs instead of snapping.
            width: root.mode === "label" ? Math.min(maxWidth, Math.max(Appearance.s(190), Appearance.s(78) + label.implicitWidth)) : Appearance.s(320)
            // A touch taller for volume, to carry the device line.
            height: root.device !== "" ? Appearance.s(72) : Appearance.s(58)

            // Only while the pill is actually on screen. Now that `drawing`
            // holds its value through the fade-out, an off-screen pill keeps the
            // previous kind's geometry — so without this the next OSD would
            // animate in *from* that size, e.g. a volume pill growing out of the
            // submap legend's 544px. Hidden: snap. Visible: morph, which is the
            // point of these Behaviors.
            Behavior on height {
                enabled: pill.visible

                Anim {
                    duration: Appearance.anim.durations.expressiveDefaultEffects
                    curve: Appearance.anim.curves.emphasized
                }
            }
            radius: height / 2
            color: Theme.surfaceBg
            border.width: 1
            border.color: Theme.surfaceBorder

            Behavior on width {
                enabled: pill.visible

                Anim {
                    duration: Appearance.anim.durations.expressiveDefaultEffects
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
            // Effects durations, not Spatial ones (350ms in / 200ms out): this
            // is an acknowledgement of a key you already pressed, so it wants to
            // be present before you look for it. At 350ms the pill was still
            // arriving after the thing it was reporting had happened.
            Behavior on anim {
                Anim {
                    duration: root.shown ? Appearance.anim.durations.expressiveDefaultEffects : Appearance.anim.durations.expressiveFastEffects
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
                // Only bites once the pill has hit its ceiling — below that the
                // pill is sized *from* implicitWidth, so this is the same
                // number and nothing elides.
                width: Math.min(implicitWidth, pill.maxWidth - Appearance.s(78))
                elide: Text.ElideRight
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
