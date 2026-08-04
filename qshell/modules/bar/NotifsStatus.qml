import QtQuick
import qs.config
import qs.components
import qs.services

// Notification bell + unseen count; click opens the notification center.
Item {
    id: root

    property var popouts: null

    implicitWidth: content.implicitWidth + Appearance.sizes.modulePad
    implicitHeight: Appearance.sizes.barInner

    StateLayer {
        hitSlop: Appearance.sizes.barSlop
        onClicked: root.popouts?.toggle("notifs", root)
        // macOS menubar: once any bar menu is open, sliding along the bar
        // switches menus without another click.
        onContainsMouseChanged: {
            if (containsMouse && root.popouts?.open && root.popouts.current !== "notifs")
                root.popouts.toggle("notifs", root);
        }
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

        // Same size/style as the battery percentage and clock text. Unseen,
        // not total: the retained-history count only ever went up, and a
        // number that never resets stops meaning anything. (badgeUnseen, not
        // unseen: the service latches it while a menu is open so this module
        // can't resize under a parked cursor mid-interaction.)
        StyledText {
            visible: Notifs.badgeUnseen > 0
            anchors.verticalCenter: parent.verticalCenter
            text: `${Notifs.badgeUnseen}`
            color: Theme.barFg
            font.weight: Font.Bold
        }
    }
}
