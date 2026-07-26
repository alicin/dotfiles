import QtQuick
import qs.config
import qs.components

// Back chevron + page title, with a slot on the right for the page's one
// primary control (the Bluetooth switch, "Open app", …).
//
// The whole title block is the back target, not just the chevron — a lone
// chevron is a ~15px hit area, and this is the only way out of a page.
Item {
    id: root

    property string title: ""

    default property alias trailing: trail.data

    signal back

    width: parent?.width ?? 0
    implicitHeight: Appearance.s(38)

    Item {
        id: backBtn

        width: backRow.implicitWidth + Appearance.s(16)
        height: parent.height

        StateLayer {
            radius: Appearance.s(10)
            color: Theme.surfaceFg
            onClicked: root.back()
        }

        Row {
            id: backRow

            anchors.centerIn: parent
            spacing: Appearance.s(5)

            FIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: "chevron_left"
                font.pixelSize: Appearance.s(15)
                color: Theme.accent
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.title
                color: Theme.surfaceFg
                font.pixelSize: Appearance.font.size.large
            }
        }
    }

    Row {
        id: trail

        anchors.right: parent.right
        anchors.rightMargin: Appearance.s(4)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Appearance.s(6)
    }
}
