import QtQuick
import Quickshell
import qs.config
import qs.components

// "Fri 25 Jul · 17:45" — date first, time second. Click opens the calendar;
// this was the only inert module on the bar.
Item {
    id: root

    property var popouts: null
    property var tooltip: null

    implicitWidth: label.implicitWidth + Appearance.sizes.modulePad
    implicitHeight: Appearance.sizes.barInner

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    StateLayer {
        hitSlop: Appearance.sizes.barSlop
        onClicked: root.popouts?.toggle("calendar", root)
        // macOS menubar: once any bar menu is open, sliding along the bar
        // switches menus without another click.
        onContainsMouseChanged: {
            if (containsMouse && root.popouts?.open && root.popouts.current !== "calendar")
                root.popouts.toggle("calendar", root);
            if (containsMouse)
                root.tooltip?.show(Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy"), root);
            else
                root.tooltip?.hide(root);
        }
    }

    StyledText {
        id: label

        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, "ddd d MMM · HH:mm")
        font.weight: Font.Bold
    }
}
