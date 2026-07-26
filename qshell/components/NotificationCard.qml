import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs.config
import qs.services

// One notification. Used by the popup stack (flat: false — bordered card
// with a drop shadow) and the bell menu list (flat: true — bare row on the
// menu surface). `wrapper` is a Notifs entry: { n: Notification, at: ms }.
Item {
    id: root

    required property var wrapper

    property bool flat: false

    readonly property real radius: Appearance.s(14)

    // n can go null for a frame while a dismissed notification is destroyed —
    // every read below is null-guarded.
    readonly property var n: wrapper?.n ?? null
    readonly property bool critical: n?.urgency === NotificationUrgency.Critical
    readonly property string imageSource: {
        if (n?.image)
            return n.image;
        if (n?.appIcon)
            return Quickshell.iconPath(n.appIcon, true) || "";
        return "";
    }

    function ago(): string {
        const s = Math.max(0, (Notifs.now - wrapper.at) / 1000);
        if (s < 60)
            return "now";
        if (s < 3600)
            return `${Math.floor(s / 60)}m`;
        if (s < 86400)
            return `${Math.floor(s / 3600)}h`;
        return `${Math.floor(s / 86400)}d`;
    }

    implicitHeight: content.implicitHeight + Appearance.s(24)

    Elevation {
        visible: !root.flat
        anchors.fill: bg
        radius: root.radius
        level: 3
    }

    Rectangle {
        id: bg

        anchors.fill: parent
        radius: root.radius
        color: root.flat ? "transparent" : Theme.surfaceBg
        border.width: root.flat ? 0 : 1
        border.color: root.critical ? Theme.urgent : Theme.surfaceBorder
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.n?.dismiss()
    }

    Column {
        id: content

        x: Appearance.s(12)
        y: Appearance.s(12)
        width: parent.width - Appearance.s(24)
        spacing: Appearance.s(6)

        Item {
            width: parent.width
            implicitHeight: Math.max(iconBox.implicitHeight, textCol.implicitHeight)

            ClippingRectangle {
                id: iconBox

                implicitWidth: Appearance.s(34)
                implicitHeight: Appearance.s(34)
                radius: Appearance.s(8)
                color: "transparent"
                visible: root.imageSource !== ""

                Image {
                    anchors.fill: parent
                    source: root.imageSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            FIcon {
                visible: root.imageSource === ""
                anchors.verticalCenter: iconBox.verticalCenter
                width: iconBox.visible ? 0 : Appearance.s(34)
                icon: "bell_fill"
                font.pixelSize: Appearance.s(19)
                color: Theme.surfaceFgDim
            }

            Column {
                id: textCol

                anchors.left: parent.left
                anchors.leftMargin: Appearance.s(44)
                anchors.right: closeBtn.left
                anchors.rightMargin: Appearance.s(8)
                spacing: Appearance.s(1)

                Item {
                    width: parent.width
                    implicitHeight: appLabel.implicitHeight

                    StyledText {
                        id: appLabel

                        anchors.left: parent.left
                        anchors.right: timeLabel.left
                        text: root.n?.appName || "notification"
                        color: Theme.surfaceFgDim
                        font.pixelSize: Appearance.font.size.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        id: timeLabel

                        anchors.right: parent.right
                        text: root.ago()
                        color: Theme.surfaceFgDim
                        font.pixelSize: Appearance.font.size.small
                    }
                }

                StyledText {
                    width: parent.width
                    text: root.n?.summary ?? ""
                    color: Theme.surfaceFg
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    visible: (root.n?.body?.length ?? 0) > 0
                    text: root.n?.body ?? ""
                    textFormat: Text.StyledText
                    color: Theme.surfaceFgDim
                    font.pixelSize: Appearance.font.size.small
                    font.weight: Font.Normal
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
            }

            Item {
                id: closeBtn

                anchors.right: parent.right
                width: Appearance.s(22)
                height: Appearance.s(22)

                StateLayer {
                    radius: width / 2
                    color: Theme.surfaceFg
                    onClicked: root.n?.dismiss()
                }

                FIcon {
                    anchors.centerIn: parent
                    icon: "xmark"
                    color: Theme.surfaceFgDim
                    font.pixelSize: Appearance.font.size.small
                }
            }
        }

        Row {
            visible: (root.n?.actions?.length ?? 0) > 0
            spacing: Appearance.s(6)

            Repeater {
                model: root.n?.actions ?? []

                Rectangle {
                    required property NotificationAction modelData

                    implicitWidth: actionLabel.implicitWidth + Appearance.s(20)
                    implicitHeight: Appearance.s(26)
                    radius: height / 2
                    color: Theme.surfaceHoverBg

                    StateLayer {
                        radius: parent.radius
                        color: Theme.surfaceFg
                        // Everything is read into locals *before* invoking:
                        // invoke() usually makes the client close the
                        // notification, which drops it from the model and
                        // destroys this delegate mid-handler. The rest of the
                        // function then runs without a QML context, and
                        // `root` — the card — resolves to nothing.
                        // (Observed: "ReferenceError: root is not defined",
                        // which is why action buttons appeared to do nothing.)
                        onClicked: {
                            const notif = root.n;
                            const resident = notif?.resident ?? false;
                            if (!Notifs.runAction(notif, parent.modelData.identifier))
                                parent.modelData.invoke();
                            if (notif && !resident)
                                notif.dismiss();
                        }
                    }

                    StyledText {
                        id: actionLabel

                        anchors.centerIn: parent
                        text: parent.modelData.text || parent.modelData.identifier
                        color: Theme.surfaceFg
                        font.pixelSize: Appearance.font.size.small
                    }
                }
            }
        }
    }
}
