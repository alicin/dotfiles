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
    property var tray: null

    // Full-color icons that turn into blobs under the monochrome tint.
    readonly property bool tinted: !/toshy/i.test(`${modelData.id} ${modelData.title}`)
    readonly property bool hasAnyMenu: modelData.onlyMenu || modelData.hasMenu

    implicitWidth: Appearance.sizes.trayCell
    implicitHeight: Appearance.sizes.barInner

    // Status changes in place don't re-notify the tray's `values` — poke its
    // revision counter so NeedsAttention can expand the row.
    Connections {
        target: root.modelData

        function onStatusChanged() {
            if (root.tray)
                root.tray.attnRev++;
        }
    }

    StateLayer {
        radius: Appearance.rounding.small
        hitSlop: Appearance.sizes.barSlop
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                root.modelData.activate();
            } else if (root.hasAnyMenu) {
                root.popouts?.toggle(`tray:${root.modelData.id}`, root, root.modelData);
            } else if (mouse.button === Qt.LeftButton) {
                root.modelData.activate();
            } else {
                root.modelData.secondaryActivate();
            }
        }
        // macOS menubar: while any bar menu is open, sliding across the tray
        // switches to each item's menu without another click.
        onContainsMouseChanged: {
            if (containsMouse && root.popouts?.open && root.hasAnyMenu && root.popouts.current !== `tray:${root.modelData.id}`)
                root.popouts.toggle(`tray:${root.modelData.id}`, root, root.modelData);
        }
    }

    // Applets that respond to the wheel (volume/brightness/player ones) never
    // saw it here — every other bar forwards scroll over a tray icon.
    // Vertical slop only, via the wrapper: a handler `margin` extends every
    // side, and with 0 spacing between cells the horizontal bleed handed the
    // wheel to the neighboring applet.
    Item {
        anchors.fill: parent
        anchors.topMargin: -Appearance.sizes.barSlop
        anchors.bottomMargin: -Appearance.sizes.barSlop

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => root.modelData.scroll(event.angleDelta.y, false)
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
