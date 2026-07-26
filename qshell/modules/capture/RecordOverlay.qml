import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Dims everything *outside* an area recording, so what's in frame is obvious
// at a glance while you work.
//
// Four rectangles around the region rather than one rectangle with a hole:
// there's no "inverse clip" primitive here, and stacking a transparent cutout
// over a dim layer would still darken the region underneath it.
//
// Nothing this draws may sit *inside* the region — it would all be in the
// recording. The frame is drawn entirely outside the boundary (Qt strokes
// borders inward, so the rect is inflated by the border width first) and the
// pill is parked above or below the region, never within it.
//
// Only the pill takes input; everywhere else the window is click-through,
// because blocking input over a recording you're actively driving would be
// worse than useless.
Scope {
    id: root

    // Hyprland's own active-window border, so a recording looks like a focused
    // window rather than an alarm. Read live rather than hardcoded — it's a
    // theme value in hypr's lua config and this should follow it.
    property color borderColor: "#ff64ad85"
    property int borderWidth: 4

    // Re-read on each recording: cheap, and picks up a theme change without a
    // shell restart.
    Connections {
        target: Capture

        function onRegionRecordingChanged(): void {
            if (Capture.regionRecording)
                hyprBorder.running = true;
        }
    }

    Process {
        id: hyprBorder

        running: true
        // The colour is a *gradient* ("ff64ad85 0deg", possibly several stops);
        // the first stop is the one to match. hyprctl reports AARRGGBB, which
        // is what Qt's #AARRGGBB literal wants, so it passes straight through.
        command: ["sh", "-c", `
            printf '%s %s' \
                "$(hyprctl -j getoption general:col.active_border | jq -r '.gradient' | awk '{print $1}')" \
                "$(hyprctl -j getoption general:border_size | jq -r '.int')"
        `]

        stdout: StdioCollector {
            onStreamFinished: {
                const [col, size] = text.trim().split(/\s+/);
                if (col && /^[0-9a-fA-F]{8}$/.test(col))
                    root.borderColor = `#${col}`;
                const n = parseInt(size, 10);
                if (n > 0)
                    root.borderWidth = n;
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property ShellScreen modelData

            readonly property int gx: Capture.rx - win.screen.x
            readonly property int gy: Capture.ry - win.screen.y
            readonly property int bw: root.borderWidth

            screen: modelData
            // Up for the armed state too, not just while rolling: that's the
            // whole point of arming — you see exactly what's framed, and what
            // audio is going in, before anything is committed to disk.
            visible: Capture.regionGeom !== ""
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0

            WlrLayershell.namespace: "qshell:recordoverlay"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // Input only where the pill is — the Stop button needs clicks, and
            // everything else must stay transparent to them.
            mask: Region {
                item: pill
            }

            component Shade: Rectangle {
                color: "#000000"
                opacity: 0.45
            }

            Shade {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: Math.max(0, win.gy)
            }

            Shade {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                y: win.gy + Capture.rh
                height: Math.max(0, win.height - (win.gy + Capture.rh))
            }

            Shade {
                anchors.left: parent.left
                y: win.gy
                width: Math.max(0, win.gx)
                height: Capture.rh
            }

            Shade {
                anchors.right: parent.right
                y: win.gy
                x: win.gx + Capture.rw
                width: Math.max(0, win.width - (win.gx + Capture.rw))
                height: Capture.rh
            }

            // Frame *around* the region, not on it: Qt strokes borders inward,
            // so the rect is inflated by the border width and the stroke lands
            // entirely outside the captured pixels. Drawing it at the region's
            // own bounds is what put a red edge in the recording.
            Rectangle {
                x: win.gx - win.bw
                y: win.gy - win.bw
                width: Capture.rw + win.bw * 2
                height: Capture.rh + win.bw * 2
                radius: win.bw
                color: "transparent"
                border.width: win.bw
                border.color: root.borderColor
            }

            // Status pill: blinking dot, elapsed time, area size, Stop. Parked
            // outside the frame — above by preference, below when the region is
            // hard against the top of the screen. Never inside: it would be in
            // the recording, and it's the one thing you'd notice.
            Rectangle {
                id: pill

                readonly property int gap: win.bw + Appearance.s(6)
                readonly property bool below: win.gy - gap < height

                x: Math.min(Math.max(Appearance.s(8), win.gx), win.width - width - Appearance.s(8))
                y: below ? win.gy + Capture.rh + gap : win.gy - height - gap
                implicitWidth: pillRow.implicitWidth + Appearance.s(18)
                implicitHeight: Appearance.s(30)
                radius: height / 2
                color: "#e6000000"

                // Pill text: white, small, and never in the recording, so it
                // doesn't go through StyledText's theme colours.
                component PillText: Text {
                    color: "#ffffff"
                    font.family: Appearance.font.family
                    font.pixelSize: Appearance.font.size.small
                    anchors.verticalCenter: parent?.verticalCenter ?? undefined
                }

                // Labelled pill button. Bare glyphs would be ambiguous on a
                // control that starts and stops writing a file.
                component PillButton: Rectangle {
                    id: btn

                    property string label: ""
                    property string glyph: ""
                    property color tint: "#33ffffff"

                    signal tapped

                    anchors.verticalCenter: parent?.verticalCenter ?? undefined
                    implicitWidth: btnRow.implicitWidth + Appearance.s(14)
                    implicitHeight: Appearance.s(22)
                    radius: height / 2
                    color: btnArea.containsMouse ? btn.tint : "#33ffffff"

                    Behavior on color {
                        CAnim {}
                    }

                    MouseArea {
                        id: btnArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: btn.tapped()
                    }

                    Row {
                        id: btnRow

                        anchors.centerIn: parent
                        spacing: Appearance.s(5)

                        FIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: btn.glyph !== ""
                            icon: btn.glyph
                            font.pixelSize: Appearance.s(11)
                            color: "#ffffff"
                        }

                        PillText {
                            text: btn.label
                            font.weight: Font.Medium
                        }
                    }
                }

                // Audio source toggle — lit when it will be captured.
                component AudioToggle: Rectangle {
                    id: tog

                    property string glyph: ""
                    property string offGlyph: ""
                    property bool on: false

                    signal tapped

                    anchors.verticalCenter: parent?.verticalCenter ?? undefined
                    implicitWidth: Appearance.s(24)
                    implicitHeight: Appearance.s(22)
                    radius: height / 2
                    color: tog.on ? "#40ffffff" : (togArea.containsMouse ? "#26ffffff" : "transparent")

                    Behavior on color {
                        CAnim {}
                    }

                    MouseArea {
                        id: togArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tog.tapped()
                    }

                    FIcon {
                        anchors.centerIn: parent
                        icon: tog.on ? tog.glyph : tog.offGlyph
                        font.pixelSize: Appearance.s(12)
                        // Dim rather than hidden when off: which sources exist
                        // is as much a part of the readout as which are armed.
                        color: tog.on ? "#ffffff" : "#80ffffff"
                    }
                }

                Row {
                    id: pillRow

                    anchors.centerIn: parent
                    spacing: Appearance.s(8)

                    // Solid while armed, blinking once it's actually writing.
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Appearance.s(9)
                        height: width
                        radius: width / 2
                        color: Capture.recording ? Theme.urgent : "#80ffffff"

                        SequentialAnimation on opacity {
                            running: Capture.recording
                            loops: Animation.Infinite
                            alwaysRunToEnd: true

                            NumberAnimation {
                                to: 0.25
                                duration: 700
                            }

                            NumberAnimation {
                                to: 1
                                duration: 700
                            }
                        }
                    }

                    PillText {
                        // Monospaced digits: the counter ticks every second and
                        // the pill would otherwise resize under the cursor,
                        // moving the Stop button as you reach for it.
                        visible: Capture.recording
                        text: Capture.elapsedText
                        font.weight: Font.Medium
                        font.features: ({
                                tnum: 1
                            })
                    }

                    PillText {
                        text: `${Capture.rw}×${Capture.rh}`
                        color: "#99ffffff"
                    }

                    AudioToggle {
                        glyph: "speaker_2_fill"
                        offGlyph: "speaker_slash_fill"
                        on: Capture.recordSystem
                        onTapped: Capture.toggleSystem()
                    }

                    AudioToggle {
                        glyph: "mic_fill"
                        offGlyph: "mic_slash_fill"
                        on: Capture.recordMic
                        onTapped: Capture.toggleMic()
                    }

                    PillButton {
                        visible: Capture.armed
                        label: "Start"
                        glyph: "play_fill"
                        tint: Theme.ok
                        onTapped: Capture.startArmed()
                    }

                    PillButton {
                        visible: Capture.recording
                        label: "Stop"
                        glyph: "stop_fill"
                        tint: Theme.urgent
                        onTapped: Capture.stopRecording()
                    }

                    // Discard an armed region without recording it.
                    PillButton {
                        visible: Capture.armed
                        label: "Cancel"
                        glyph: "xmark"
                        onTapped: Capture.disarm()
                    }
                }
            }
        }
    }
}
