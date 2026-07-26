import QtQuick
import Quickshell
import qs.config
import qs.components

// "Fri 25 Jul · 17:45" — date first, time second.
Item {
    implicitWidth: label.implicitWidth + Appearance.sizes.modulePad
    implicitHeight: Appearance.sizes.barInner

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    StyledText {
        id: label

        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, "ddd d MMM · HH:mm")
        font.weight: Font.Bold
    }
}
