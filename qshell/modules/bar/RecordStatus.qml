import QtQuick
import qs.config
import qs.components
import qs.services

// Recording indicator: blinking dot + elapsed, click to stop.
//
// The dim overlay's pill already says all this — but only for an *area*
// recording, and only on the screen holding the region. A full-screen
// recording draws no overlay at all, so before this the only sign the machine
// was recording was the Control Center's collapsed capture row, two clicks in.
// This is the one indicator that is always up and on every monitor.
Item {
    id: root

    property var tooltip: null

    visible: Capture.recording || Capture.paused
    implicitWidth: visible ? content.implicitWidth + Appearance.s(14) : 0
    implicitHeight: Appearance.sizes.barInner

    StateLayer {
        hitSlop: Appearance.sizes.barSlop
        radius: Appearance.rounding.full
        // Left stops and saves; the pill on the overlay is the only other way
        // and a full-screen recording doesn't have one.
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                Capture.togglePause();
            else
                Capture.stopRecording();
        }
        onContainsMouseChanged: {
            if (containsMouse)
                root.tooltip?.show(Capture.paused ? "Recording paused — click to save, right-click to resume" : "Recording — click to stop, right-click to pause", root);
            else
                root.tooltip?.hide(root);
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: root.width - Appearance.s(2)
        height: Appearance.sizes.barInner
        radius: height * 0.38
        color: Qt.alpha(Theme.barUrgent, 0.9)
    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: Appearance.s(6)

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Appearance.s(8)
            height: width
            radius: width / 2
            color: "#ffffff"

            // Blinks while writing, solid while paused — the same language the
            // overlay pill speaks, so the two can't tell different stories.
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

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            // Monospaced digits: the counter ticks every second and the chip
            // would otherwise resize under the cursor, moving itself out from
            // under the click that means to stop it.
            text: Capture.elapsedText
            color: "#ffffff"
            font.weight: Font.Bold
            font.features: ({
                    tnum: 1
                })
        }
    }
}
