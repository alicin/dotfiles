import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Dims everything *outside* an area recording, so what's in frame is obvious
// at a glance while you work.
//
// Four rectangles around the region rather than one rectangle with a hole:
// there's no "inverse clip" primitive here, and stacking a transparent cutout
// over a dim layer would still darken the region underneath it.
//
// The window is entirely click-through — an empty input mask — because this is
// pure annotation. Blocking input over a recording you're actively driving
// would be worse than useless.
Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property ShellScreen modelData

            readonly property int gx: Capture.rx - win.screen.x
            readonly property int gy: Capture.ry - win.screen.y

            screen: modelData
            visible: Capture.regionRecording
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

            // No input region at all: pointer events pass straight through.
            mask: Region {}

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

            // Frame the live area so the boundary is unambiguous.
            Rectangle {
                x: win.gx
                y: win.gy
                width: Capture.rw
                height: Capture.rh
                color: "transparent"
                border.width: 2
                border.color: Theme.urgent
            }

            // Recording pill, parked just outside the region (or just inside,
            // when the region is hard against the top of the screen).
            Rectangle {
                readonly property bool below: win.gy < height + Appearance.s(12)

                x: Math.min(Math.max(Appearance.s(8), win.gx), win.width - width - Appearance.s(8))
                y: below ? win.gy + Appearance.s(8) : win.gy - height - Appearance.s(8)
                implicitWidth: pill.implicitWidth + Appearance.s(22)
                implicitHeight: Appearance.s(28)
                radius: height / 2
                color: "#cc000000"

                Row {
                    id: pill

                    anchors.centerIn: parent
                    spacing: Appearance.s(7)

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Appearance.s(9)
                        height: width
                        radius: width / 2
                        color: Theme.urgent

                        SequentialAnimation on opacity {
                            running: Capture.regionRecording
                            loops: Animation.Infinite

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

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${Capture.rw}×${Capture.rh}`
                        color: "#ffffff"
                        font.family: Appearance.font.family
                        font.pixelSize: Appearance.font.size.small
                    }
                }
            }
        }
    }
}
