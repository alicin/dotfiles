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

    // Only after the menu has dwelt open does it count as "the user saw
    // these": hover-slide can flash this menu for 50ms in transit to another
    // module, and a pass-through must neither absorb toasts nor clear the
    // badge. The badge write itself is further deferred by requestSeen until
    // every menu is closed — see the note in services/Notifs.qml.
    Timer {
        id: dwell

        interval: 600
        running: true
        onTriggered: Notifs.absorbPopups()
    }

    Component.onDestruction: {
        if (!dwell.running)
            Notifs.requestSeen();
    }

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
        // Short lists shouldn't drag-bounce; long ones stop at their ends —
        // same treatment as the wifi network list.
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        // No phantom selection until the keyboard asks for one.
        currentIndex: -1
        highlightMoveDuration: Appearance.anim.durations.expressiveFastEffects
        highlightResizeDuration: Appearance.anim.durations.expressiveFastEffects

        highlight: Rectangle {
            radius: Appearance.s(10)
            color: Theme.surfaceHoverBg
        }

        // Dismissals slide out the way toasts slide in; survivors glide up
        // instead of teleporting.
        remove: Transition {
            Anim {
                properties: "opacity"
                to: 0
                duration: Appearance.anim.durations.expressiveFastEffects
            }

            Anim {
                properties: "x"
                to: Appearance.s(24)
                duration: Appearance.anim.durations.expressiveFastEffects
            }
        }

        displaced: Transition {
            Anim {
                properties: "y"
                curve: Appearance.anim.curves.emphasized
                duration: Appearance.anim.durations.small
            }
        }

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

        // Thin scroll indicator — only while there's more than fits.
        // Explicitly parented to the viewport: children declared inside a
        // Flickable get reparented to contentItem and scroll away with it.
        Rectangle {
            parent: list
            anchors.right: parent.right
            anchors.rightMargin: Appearance.s(2)
            width: Appearance.s(3)
            radius: width / 2
            color: Qt.alpha(Theme.surfaceFg, 0.28)
            visible: list.interactive
            height: list.height * (list.height / Math.max(list.contentHeight, 1))
            y: list.contentY * (list.height / Math.max(list.contentHeight, 1))
        }
    }

    // Keyboard nav, driven by the Popouts FocusScope: arrows select, Enter
    // opens (the card's default action / expand), Delete dismisses.
    function navMove(d: int): void {
        if (list.count === 0)
            return;
        list.currentIndex = Math.max(0, Math.min(list.count - 1, list.currentIndex + d));
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
    }

    function navActivate(): void {
        list.currentItem?.activate();
    }

    function navRemove(): void {
        list.currentItem?.n?.dismiss();
    }
}
