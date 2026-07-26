import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property DesktopEntry modelData

    signal activated

    width: ListView.view ? ListView.view.width : 0
    height: Appearance.sizes.launcherItemHeight

    StateLayer {
        radius: Appearance.s(16)
        color: Theme.surfaceFg
        onClicked: {
            Apps.launch(root.modelData);
            root.activated();
        }
    }

    IconImage {
        id: icon

        anchors.left: parent.left
        anchors.leftMargin: Appearance.s(10)
        anchors.verticalCenter: parent.verticalCenter
        implicitSize: Appearance.s(38)
        asynchronous: true
        source: (root.modelData.icon && Quickshell.iconPath(root.modelData.icon, true)) || Quickshell.iconPath("application-x-executable", true) || ""
    }

    Column {
        anchors.left: icon.right
        anchors.leftMargin: Appearance.s(12)
        anchors.right: parent.right
        anchors.rightMargin: Appearance.s(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        StyledText {
            width: parent.width
            text: root.modelData.name
            color: Theme.surfaceFg
            elide: Text.ElideRight
        }

        StyledText {
            width: parent.width
            visible: text.length > 0
            text: root.modelData.comment || root.modelData.genericName || ""
            color: Theme.surfaceFgDim
            font.pixelSize: Appearance.font.size.small
            font.weight: Font.Normal
            elide: Text.ElideRight
        }
    }
}
