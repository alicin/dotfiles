import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config
import qs.components

Item {
    id: root

    required property SystemTrayItem modelData

    property var popouts: null

    // Full-color icons that turn into blobs under the monochrome tint.
    readonly property bool tinted: !/toshy/i.test(`${modelData.id} ${modelData.title}`)

    implicitWidth: Appearance.sizes.trayCell
    implicitHeight: Appearance.sizes.barInner

    StateLayer {
        radius: Appearance.rounding.small
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                root.modelData.activate();
            } else if (root.modelData.onlyMenu || root.modelData.hasMenu) {
                root.popouts?.toggle(`tray:${root.modelData.id}`, root, root.modelData);
            } else if (mouse.button === Qt.LeftButton) {
                root.modelData.activate();
            } else {
                root.modelData.secondaryActivate();
            }
        }
    }

    // Uniform monochrome tray (macOS-style): ColorOverlay replaces the icon's
    // color with the bar fg while keeping alpha — unlike MultiEffect
    // colorization, this turns dark pixmaps white instead of black. Needed
    // because some apps (nm-applet, blueman) send pre-rendered pixmaps drawn
    // against the global (light) gtk icon theme.
    IconImage {
        id: icon

        anchors.centerIn: parent
        implicitSize: Appearance.sizes.icon
        asynchronous: true
        source: root.modelData.icon
        visible: !root.tinted
    }

    ColorOverlay {
        visible: root.tinted
        anchors.fill: icon
        source: icon
        color: Theme.barFg
    }
}
