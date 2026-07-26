import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// One window in the overview: live ScreencopyView thumbnail at the window's
// real (scaled) geometry, app icon centered. Click focuses, middle-click
// closes, drag moves it to another workspace (drop detection via the cells'
// DropAreas — the end-4/dots-hyprland approach).
Item {
    id: root

    required property var modelData // HyprlandToplevel
    required property var view //      the overview window (metrics)
    required property var overview //  the overview scope (open/drag state)

    readonly property string addr: modelData.lastIpcObject?.address ?? ""
    // Prefer the overview's freshly-fetched clients json; lastIpcObject is
    // only the fallback for the first frames.
    readonly property var info: overview.clients[addr] ?? modelData.lastIpcObject
    readonly property int wsId: info?.workspace?.id ?? -1
    readonly property bool floating: info?.floating ?? false

    readonly property real pw: Math.max(Appearance.s(12), Math.min((info?.size?.[0] ?? 10) * view.wsScale, view.cellW))
    readonly property real ph: Math.max(Appearance.s(10), Math.min((info?.size?.[1] ?? 10) * view.wsScale, view.cellH))

    readonly property real px: {
        overview.rev;
        const at = info?.at ?? [0, 0];
        const local = Math.max((at[0] - (view.monX ?? 0) - view.reserved[0]) * view.wsScale, 0);
        return view.wsCol(wsId) * (view.cellW + view.gap) + Math.min(local, view.cellW - pw);
    }
    readonly property real py: {
        overview.rev;
        const at = info?.at ?? [0, 0];
        const local = Math.max((at[1] - (view.monY ?? 0) - view.reserved[1]) * view.wsScale, 0);
        return view.wsRow(wsId) * (view.cellH + view.gap) + Math.min(local, view.cellH - ph);
    }

    // x/y are deliberately unbound (drag writes them); re-sync whenever the
    // layout targets change and we're not mid-drag.
    function sync(): void {
        if (!dragArea.drag.active) {
            x = px;
            y = py;
        }
    }

    onPxChanged: sync()
    onPyChanged: sync()
    Component.onCompleted: sync()

    // drag.active can still read true inside onReleased — settle shortly
    // after, and again once the post-move refetch lands (px/py change).
    Timer {
        id: settle

        interval: 140
        onTriggered: root.sync()
    }

    width: pw
    height: ph
    z: dragArea.drag.active ? 99 : root.floating ? 3 : 2

    Behavior on x {
        enabled: !dragArea.drag.active

        Anim {
            curve: Appearance.anim.curves.emphasized
            duration: Appearance.anim.durations.expressiveSlowEffects
        }
    }

    Behavior on y {
        enabled: !dragArea.drag.active

        Anim {
            curve: Appearance.anim.curves.emphasized
            duration: Appearance.anim.durations.expressiveSlowEffects
        }
    }

    Drag.active: dragArea.drag.active
    Drag.source: root

    ClippingRectangle {
        anchors.fill: parent
        radius: Appearance.s(6)
        color: Qt.alpha("#000000", 0.35)
        border.width: 1
        border.color: dragArea.containsMouse ? Theme.accent : Qt.alpha(Theme.surfaceFg, 0.25)

        ScreencopyView {
            anchors.fill: parent
            captureSource: root.overview.open ? (root.modelData.wayland ?? null) : null
            live: true
        }

        Rectangle {
            anchors.fill: parent
            color: dragArea.containsMouse ? Qt.alpha(Theme.accent, 0.10) : "transparent"
        }

        IconImage {
            anchors.centerIn: parent
            implicitSize: Math.min(root.pw, root.ph) * 0.4
            asynchronous: true
            source: Apps.toplevelIcon(root.modelData)
        }
    }

    MouseArea {
        id: dragArea

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        drag.target: root

        onPressed: mouse => {
            root.overview.dragWs = root.wsId;
            root.Drag.hotSpot.x = mouse.x;
            root.Drag.hotSpot.y = mouse.y;
        }

        onReleased: mouse => {
            root.overview.dragWs = -1;
            root.overview.dropWs = -1;

            // Geometric drop target: map the release point into the grid and
            // resolve the cell — robust against DropArea enter/exit races and
            // drops landing on the gaps between cells.
            const p = root.parent.mapFromItem(root, mouse.x, mouse.y);
            const tol = Appearance.s(24);
            let target = -1;
            if (p.x > -tol && p.y > -tol && p.x < root.view.cols * (root.view.cellW + root.view.gap) + tol && p.y < root.view.rows * (root.view.cellH + root.view.gap) + tol) {
                const col = Math.max(0, Math.min(root.view.cols - 1, Math.floor(p.x / (root.view.cellW + root.view.gap))));
                const row = Math.max(0, Math.min(root.view.rows - 1, Math.floor(p.y / (root.view.cellH + root.view.gap))));
                target = row * root.view.cols + col + 1;
                if (target > Settings.workspaces)
                    target = -1;
            }

            if (target !== -1 && target !== root.wsId)
                Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${target}, follow = false, window = "address:${root.addr}" })`);

            Qt.callLater(() => root.sync());
            settle.restart();
        }

        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                Hyprland.dispatch(`hl.dsp.window.close({ window = "address:${root.addr}" })`);
                return;
            }
            root.overview.open = false;
            Hyprland.dispatch(`hl.dsp.focus({ window = "address:${root.addr}" })`);
        }
    }
}
