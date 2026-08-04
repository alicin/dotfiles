import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property DesktopEntry modelData
    required property int index

    // The active search text, for match highlighting.
    property string query: ""

    signal activated

    width: ListView.view ? ListView.view.width : 0
    height: Appearance.sizes.launcherItemHeight

    StateLayer {
        radius: Appearance.s(16)
        color: Theme.surfaceFg
        // No private wash: hover moves the list's selection instead, so there
        // is exactly one highlight and Enter always launches what looks
        // active — hover and keyboard used to disagree.
        hoverOpacity: 0
        // Selection follows *real* pointer motion only, filtered on window
        // coordinates: Qt re-delivers hover every frame that content slides
        // under a stationary cursor (keyboard scroll, result churn, the
        // height animation), and honoring those yanked the selection back to
        // the hovered row on every keystroke. The first report after open
        // only calibrates, so the panel rising through a parked cursor can't
        // steal the selection either.
        function hoverSelect(): void {
            const view = root.ListView.view;
            if (!view)
                return;
            const p = mapToItem(null, mouseX, mouseY);
            const first = view.lastHoverPos.x < -1e8;
            if (!first && p.x === view.lastHoverPos.x && p.y === view.lastHoverPos.y)
                return;
            view.lastHoverPos = Qt.point(p.x, p.y);
            if (!first)
                view.currentIndex = root.index;
        }

        onContainsMouseChanged: {
            if (containsMouse)
                hoverSelect();
        }
        onPositionChanged: hoverSelect()
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
            textFormat: Text.StyledText
            text: Apps.markMatches(root.modelData.name, root.query)
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
