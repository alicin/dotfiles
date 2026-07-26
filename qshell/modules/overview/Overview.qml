import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.components

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

    function refetch(): void {
        clientsProc.running = true;
    }

    onOpenChanged: {
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
                Keys.onEscapePressed: root.open = false

                Elevation {
                    anchors.fill: panel
                    radius: panel.radius
                    level: 4
                }

                Rectangle {
                    id: panel

                    anchors.centerIn: parent
                    width: grid.width + Appearance.s(24)
                    height: grid.height + Appearance.s(24)
                    radius: Appearance.s(20)
                    color: Theme.surfaceBg
                    border.width: 1
                    border.color: Theme.surfaceBorder

                    Item {
                        id: grid

                        anchors.centerIn: parent
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
                                values: root.rev >= 0 ? Hyprland.toplevels.values.filter(t => {
                                    const ws = t.workspace?.id ?? -1;
                                    return ws >= 1 && ws <= Settings.workspaces;
                                }) : []
                            }

                            OverviewWindow {
                                view: win
                                overview: root
                            }
                        }
                    }
                }
            }
        }
    }
}
