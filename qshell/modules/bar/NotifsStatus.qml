import QtQuick
import qs.config
import qs.components
import qs.services

// Notification bell + count; click opens the notification center.
Item {
    id: root

    property var popouts: null

    implicitWidth: content.implicitWidth + Appearance.sizes.modulePad
    implicitHeight: Appearance.sizes.barInner

    StateLayer {
        onClicked: root.popouts?.toggle("notifs", root)
    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: Appearance.s(4)

        FIcon {
            anchors.verticalCenter: parent.verticalCenter
            icon: Notifs.dnd ? "bell_slash" : "app_badge_fill"
            color: Notifs.dnd ? Theme.barFgDim : Theme.barFg
        }

        // Same size/style as the battery percentage and clock text.
        StyledText {
            visible: Notifs.count > 0
            anchors.verticalCenter: parent.verticalCenter
            text: `${Notifs.count}`
            color: Theme.barFg
            font.weight: Font.Bold
        }
    }
}
