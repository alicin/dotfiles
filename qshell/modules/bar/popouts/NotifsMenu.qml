import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// Notification center: DND toggle, clear-all, recent notifications.
Column {
    id: root

    width: Appearance.s(400)
    spacing: Appearance.s(2)

    // Opening the center absorbs pending toasts — they're all in the list.
    Component.onCompleted: Notifs.popups = []

    Item {
        width: parent.width
        height: Appearance.sizes.menuRowHeight

        StyledText {
            id: title

            anchors.verticalCenter: parent.verticalCenter
            text: "Notifications"
            color: Theme.surfaceFg
        }

        StyledText {
            anchors.left: title.right
            anchors.leftMargin: Appearance.s(8)
            anchors.verticalCenter: parent.verticalCenter
            visible: Notifs.count > 0
            text: `${Notifs.count}`
            color: Theme.surfaceFgDim
            font.pixelSize: Appearance.font.size.small
        }

        Rectangle {
            visible: Notifs.count > 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: clearLabel.implicitWidth + Appearance.s(20)
            implicitHeight: Appearance.s(26)
            radius: height / 2
            color: Theme.surfaceHoverBg

            StateLayer {
                radius: parent.radius
                color: Theme.surfaceFg
                onClicked: Notifs.clearAll()
            }

            StyledText {
                id: clearLabel

                anchors.centerIn: parent
                text: "Clear"
                color: Theme.surfaceFg
                font.pixelSize: Appearance.font.size.small
            }
        }
    }

    Item {
        width: parent.width
        height: Appearance.sizes.menuRowHeight

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: "Do not disturb"
            color: Theme.surfaceFg
        }

        StyledSwitch {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: Notifs.dnd
            onToggled: Notifs.toggleDnd()
        }
    }

    MenuSeparator {
        width: parent.width
    }

    StyledText {
        visible: Notifs.count === 0
        height: Appearance.sizes.menuRowHeight
        text: "No notifications"
        color: Theme.surfaceFgDim
    }

    ListView {
        id: list

        width: parent.width
        implicitHeight: Math.min(contentHeight, Appearance.s(430))
        visible: Notifs.count > 0
        clip: true
        spacing: Appearance.s(4)

        WheelScroll {
            view: list
        }

        model: ScriptModel {
            values: Notifs.list
        }

        delegate: NotificationCard {
            required property var modelData

            width: list.width
            wrapper: modelData
            flat: true
        }
    }
}
