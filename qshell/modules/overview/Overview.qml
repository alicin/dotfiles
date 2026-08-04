import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// Workspace overview (end-4/dots-hyprland style): a grid of all workspaces
// with live window thumbnails. Click a workspace to switch, click a window
// to focus it, drag a window onto another cell to move it there,
// middle-click to close it. Toggle: `qs ipc -c qshell call overview toggle`
// (bound to Super+Tab via apps.lua).
Scope {
    id: root

    property bool open: false
    property int rev: 0
    property int dragWs: -1
    property int dropWs: -1

    // Fresh `hyprctl clients` json by address. HyprlandToplevel.lastIpcObject
    // goes stale after moves — end-4 solves this with an event-driven refetch
    // (their HyprlandData service); same approach here.
    property var clients: ({})

    // `hyprctl monitors` by id: each window maps against ITS OWN monitor's
    // geometry — mapping everything against the overview's monitor scrambled
    // the external screen's workspaces into cell corners.
    property var monitors: ({})

    // Keyboard selection, by identity so model churn self-heals.
    property var selWin: null

    function refetch(): void {
        clientsProc.running = true;
        monitorsProc.running = true;
    }

    function orderedWins(): var {
        return win.wins.slice().sort((a, b) => {
            const wa = a.workspace?.id ?? 0;
            const wb = b.workspace?.id ?? 0;
            if (wa !== wb)
                return wa - wb;
            const aa = root.clients[((a.lastIpcObject?.address ?? "") + "")]?.at ?? [0, 0];
            const bb = root.clients[((b.lastIpcObject?.address ?? "") + "")]?.at ?? [0, 0];
            return aa[0] - bb[0];
        });
    }

    function selMove(d: int): void {
        const list = orderedWins();
        if (list.length === 0)
            return;
        let i = list.indexOf(root.selWin);
        i = i < 0 ? (d > 0 ? 0 : list.length - 1) : (i + d + list.length) % list.length;
        root.selWin = list[i];
    }

    function selFocus(): void {
        const w = root.selWin;
        if (!w)
            return;
        const addr = ((w.lastIpcObject?.address ?? "") + "");
        root.open = false;
        if (addr)
            Hyprland.dispatch(`hl.dsp.focus({ window = "address:${addr}" })`);
    }

    onOpenChanged: {
        selWin = null;
        if (open) {
            rev++;
            refetch();
        } else {
            dragWs = -1;
            dropWs = -1;
        }
    }

    Timer {
        id: refetchDelay

        interval: 80
        onTriggered: root.refetch()
    }

    Process {
        id: clientsProc

        command: ["hyprctl", "-j", "clients"]

        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                try {
                    for (const c of JSON.parse(text))
                        map[c.address] = c;
                } catch (e) {}
                root.clients = map;
                root.rev++;
            }
        }
    }

    Process {
        id: monitorsProc

        command: ["hyprctl", "-j", "monitors"]

        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                try {
                    for (const m of JSON.parse(text))
                        map[m.id] = m;
                } catch (e) {}
                root.monitors = map;
                root.rev++;
            }
        }
    }

    IpcHandler {
        target: "overview"

        function toggle(): void {
            root.open = !root.open;
        }

        function open(): void {
            root.open = true;
        }

        function close(): void {
            root.open = false;
        }
    }

    Connections {
        target: Hyprland
        enabled: root.open

        function onRawEvent(event) {
            const n = event.name;
            if (n === "openwindow" || n === "closewindow" || n === "movewindowv2" || n === "movewindow" || n === "changefloatingmode" || n === "fullscreen") {
                root.rev++;
                refetchDelay.restart();
            }
        }
    }

    PanelWindow {
        id: win

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        WlrLayershell.namespace: "qshell:overview"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        mask: Region {
            item: root.open ? backdrop : null
        }

        HyprlandFocusGrab {
            active: root.open
            windows: [win]
            onCleared: root.open = false
        }

        // ── Metrics ──
        readonly property HyprlandMonitor mon: Hyprland.monitorFor(win.screen)
        readonly property var monInfo: mon?.lastIpcObject ?? null
        readonly property real monX: monInfo?.x ?? 0
        readonly property real monY: monInfo?.y ?? 0
        readonly property var reserved: monInfo?.reserved ?? [0, 0, 0, 0]
        readonly property real usableW: (mon ? mon.width / mon.scale : width) - reserved[0] - reserved[2]
        readonly property real usableH: (mon ? mon.height / mon.scale : height) - reserved[1] - reserved[3]

        readonly property int cols: Settings.overviewColumns
        readonly property int rows: Math.ceil(Settings.workspaces / cols)
        readonly property real gap: Appearance.s(8)
        readonly property real cellW: Math.min(Appearance.s(280), (width - Appearance.s(120) - (cols - 1) * gap) / cols)
        readonly property real wsScale: cellW / usableW
        readonly property real cellH: usableH * wsScale

        function wsCol(id: int): int {
            return (id - 1) % cols;
        }

        function wsRow(id: int): int {
            return Math.floor((id - 1) / cols);
        }

        function focusWs(id: int): void {
            root.open = false;
            Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`);
        }

        // The windows on screen — one list feeding both the Repeater and the
        // keyboard-selection order.
        readonly property var wins: root.rev >= 0 ? Hyprland.toplevels.values.filter(t => {
            const ws = t.workspace?.id ?? -1;
            return ws >= 1 && ws <= Settings.workspaces;
        }) : []

        // Scratchpads: always both of the bound ones (they're drop targets
        // even when empty), plus any other populated special workspace.
        readonly property var specials: {
            root.rev;
            const names = ["special", "special:void"];
            for (const w of Hyprland.workspaces.values)
                if (w.id < 0 && !names.includes(w.name))
                    names.push(w.name);
            return names;
        }

        function specialWsId(name: string): int {
            root.rev;
            return Hyprland.workspaces.values.find(w => w.name === name)?.id ?? 0;
        }

        function toggleSpecial(name: string): void {
            const arg = name === "special" ? "" : name.replace(/^special:/, "");
            root.open = false;
            Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.workspace.toggle_special("${arg}")` : `togglespecialworkspace ${arg}`);
        }

        // Which scratchpad a point (in grid coordinates) lands on — the
        // windows' geometric drop resolution consults this for the strip
        // below the grid before trying the numbered cells.
        function specialAt(px: real, py: real): string {
            const rowY = rows * (cellH + gap) - gap + Appearance.s(8);
            if (py < rowY || py > rowY + Appearance.s(46))
                return "";
            // Same horizontal tolerance as the numbered cells — the index
            // clamp alone mapped a release far off the panel's edge onto the
            // first/last chip instead of cancelling the drop.
            const wTot = cols * (cellW + gap) - gap;
            const tol = Appearance.s(24);
            if (px < -tol || px > wTot + tol)
                return "";
            const n = specials.length;
            const i = Math.max(0, Math.min(n - 1, Math.floor(px / (wTot / n))));
            return specials[i];
        }

        Rectangle {
            id: backdrop

            anchors.fill: parent
            color: "#59000000"
            opacity: root.open ? 1 : 0
            visible: opacity > 0.01

            Behavior on opacity {
                Anim {
                    duration: Appearance.anim.durations.expressiveSlowEffects
                    curve: Appearance.anim.curves.expressiveSlowEffects
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.open = false
            }

            FocusScope {
                anchors.fill: parent
                focus: true
                // The overview sits on Alt+Tab and only ever handled Escape —
                // now: Tab/arrows/hjkl walk a selection ring across windows,
                // Enter focuses it, digits jump straight to that workspace.
                Keys.onPressed: event => {
                    const k = event.key;
                    if (k === Qt.Key_Escape) {
                        root.open = false;
                    } else if (k === Qt.Key_Tab || k === Qt.Key_Right || k === Qt.Key_Down || k === Qt.Key_L || k === Qt.Key_J) {
                        root.selMove(1);
                    } else if (k === Qt.Key_Backtab || k === Qt.Key_Left || k === Qt.Key_Up || k === Qt.Key_H || k === Qt.Key_K) {
                        root.selMove(-1);
                    } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                        root.selFocus();
                    } else if (k >= Qt.Key_1 && k <= Qt.Key_9) {
                        win.focusWs(k - Qt.Key_0);
                    } else if (k === Qt.Key_0) {
                        win.focusWs(10);
                    } else {
                        return;
                    }
                    event.accepted = true;
                }

                Elevation {
                    anchors.fill: panel
                    radius: panel.radius
                    level: 4
                }

                Rectangle {
                    id: panel

                    anchors.centerIn: parent
                    width: grid.width + Appearance.s(24)
                    height: grid.height + specialsRow.height + Appearance.s(32)
                    radius: Appearance.s(20)
                    color: Theme.surfaceBg
                    border.width: 1
                    border.color: Theme.surfaceBorder
                    // Entrance to match the launcher's spring — the panel used
                    // to just appear at full size inside the backdrop fade.
                    scale: root.open ? 1 : 0.96

                    Behavior on scale {
                        Anim {
                            curve: Appearance.anim.curves.expressiveDefaultSpatial
                            duration: Appearance.anim.durations.expressiveDefaultSpatial
                        }
                    }

                    Item {
                        id: grid

                        x: Appearance.s(12)
                        y: Appearance.s(12)
                        width: win.cols * win.cellW + (win.cols - 1) * win.gap
                        height: win.rows * win.cellH + (win.rows - 1) * win.gap

                        // ── Workspace cells ──
                        Repeater {
                            model: Settings.workspaces

                            Rectangle {
                                id: cell

                                required property int index

                                readonly property int wsId: index + 1
                                property bool dropHover: false

                                x: win.wsCol(wsId) * (win.cellW + win.gap)
                                y: win.wsRow(wsId) * (win.cellH + win.gap)
                                width: win.cellW
                                height: win.cellH
                                radius: Appearance.s(10)
                                color: dropHover ? Qt.alpha(Theme.accent, 0.16) : Theme.surfaceHoverBg
                                border.width: 1
                                border.color: dropHover ? Theme.accent : Theme.surfaceBorder

                                StyledText {
                                    anchors.centerIn: parent
                                    text: cell.wsId
                                    font.pixelSize: win.cellH * 0.4
                                    color: Qt.alpha(Theme.surfaceFg, 0.12)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: win.focusWs(cell.wsId)
                                }

                                DropArea {
                                    anchors.fill: parent
                                    onEntered: {
                                        root.dropWs = cell.wsId;
                                        cell.dropHover = root.dragWs !== cell.wsId;
                                    }
                                    onExited: {
                                        cell.dropHover = false;
                                        if (root.dropWs === cell.wsId)
                                            root.dropWs = -1;
                                    }
                                }
                            }
                        }

                        // ── Focused workspace ring ──
                        Rectangle {
                            readonly property int aws: Math.round(Math.max(1, Math.min(Settings.workspaces, Hyprland.focusedWorkspace?.id ?? 1)))

                            x: win.wsCol(aws) * (win.cellW + win.gap)
                            y: win.wsRow(aws) * (win.cellH + win.gap)
                            z: 5
                            width: win.cellW
                            height: win.cellH
                            radius: Appearance.s(10)
                            color: "transparent"
                            border.width: 2
                            border.color: Theme.accent

                            Behavior on x {
                                Anim {
                                    curve: Appearance.anim.curves.emphasized
                                }
                            }

                            Behavior on y {
                                Anim {
                                    curve: Appearance.anim.curves.emphasized
                                }
                            }
                        }

                        // ── Windows ──
                        Repeater {
                            model: ScriptModel {
                                values: win.wins
                            }

                            OverviewWindow {
                                view: win
                                overview: root
                            }
                        }
                    }

                    // ── Scratchpads ──
                    // The two daily specials were invisible here: windows
                    // parked on them appeared in no cell, and there was no
                    // drop target to move one in or out. Click toggles the
                    // scratchpad; dragging a window onto a chip parks it there
                    // (resolved geometrically in OverviewWindow.onReleased).
                    Row {
                        id: specialsRow

                        x: Appearance.s(12)
                        anchors.top: grid.bottom
                        anchors.topMargin: Appearance.s(8)
                        spacing: win.gap
                        height: Appearance.s(46)

                        Repeater {
                            model: win.specials

                            Rectangle {
                                id: spCell

                                required property var modelData

                                readonly property int swsId: win.specialWsId(modelData)
                                readonly property var stops: root.rev >= 0 && swsId !== 0 ? Hyprland.toplevels.values.filter(t => t.workspace?.id === spCell.swsId) : []
                                property bool dropHover: false

                                width: (grid.width - (win.specials.length - 1) * win.gap) / win.specials.length
                                height: parent.height
                                radius: Appearance.s(10)
                                color: dropHover ? Qt.alpha(Theme.accent, 0.16) : Theme.surfaceHoverBg
                                border.width: 1
                                border.color: dropHover ? Theme.accent : Theme.surfaceBorder

                                StyledText {
                                    x: Appearance.s(10)
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: spCell.modelData === "special" ? "Scratchpad" : spCell.modelData.replace("special:", "")
                                    color: Theme.surfaceFgDim
                                    font.pixelSize: Appearance.font.size.small
                                }

                                Row {
                                    anchors.right: parent.right
                                    anchors.rightMargin: Appearance.s(10)
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Appearance.s(4)

                                    Repeater {
                                        model: ScriptModel {
                                            values: spCell.stops.slice(0, 5)
                                        }

                                        IconImage {
                                            required property var modelData

                                            anchors.verticalCenter: parent.verticalCenter
                                            implicitSize: Appearance.s(18)
                                            asynchronous: true
                                            source: Apps.toplevelIcon(modelData)
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: win.toggleSpecial(spCell.modelData)
                                }

                                DropArea {
                                    anchors.fill: parent
                                    onEntered: spCell.dropHover = true
                                    onExited: spCell.dropHover = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
