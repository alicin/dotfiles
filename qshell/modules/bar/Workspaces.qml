import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// Fixed row of workspaces (count from settings.json): empty ones are hollow
// circles, populated ones show their apps' icons. The focused workspace gets
// a pill that slides *and stretches* between slots — leading edge fast,
// trailing edge slow, both on the M3 emphasized curve (caelestia's
// ActiveIndicator, turned horizontal). Scratchpads get their own chips after
// the numbered row.
Item {
    id: root

    required property ShellScreen screen

    // Hyprland.toplevels.values doesn't re-notify when an existing window
    // hops workspaces, so bump a revision counter from raw IPC events and
    // reference it in the occupancy bindings.
    property int rev: 0
    property list<int> urgentIds: []

    // This bar's monitor, not the global focus: with two screens, each bar now
    // highlights what its own monitor is showing rather than both mirroring
    // wherever the cursor is. (activeWorkspace stays the underlying workspace
    // while a scratchpad overlays it, which also keeps the pill from vanishing
    // when one is focused — the scratchpad has its own chip.)
    readonly property var monitor: Hyprland.monitorFor(root.screen)
    readonly property int focusedIdx: (monitor?.activeWorkspace?.id ?? 1) - 1

    function focusWorkspace(ws: string): void {
        Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.focus({ workspace = "${ws}" })` : `workspace ${ws}`);
    }

    function toggleSpecial(name: string): void {
        // "special" is the unnamed scratchpad; named ones are "special:void".
        const arg = name === "special" ? "" : name.replace(/^special:/, "");
        Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.workspace.toggle_special("${arg}")` : `togglespecialworkspace ${arg}`);
    }

    implicitWidth: row.implicitWidth + 6 + (specials.implicitWidth > 0 ? specials.implicitWidth + Appearance.s(6) : 0)
    implicitHeight: Appearance.sizes.barInner

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            const n = event.name;
            if (n === "openwindow" || n === "closewindow" || n === "movewindowv2" || n === "movewindow") {
                root.rev++;
            } else if (n === "activespecial" || n === "activespecialv2") {
                // The scratchpad chips read the monitor's specialWorkspace off
                // lastIpcObject, which only updates when monitors are refetched.
                Hyprland.refreshMonitors();
                root.rev++;
            } else if (n === "urgent") {
                const addr = event.data.trim().replace("0x", "");
                const top = Hyprland.toplevels.values.find(t => ((t.lastIpcObject?.address ?? "") + "").replace("0x", "") === addr);
                const id = top?.workspace?.id;
                if (id && id !== Hyprland.focusedWorkspace?.id && !root.urgentIds.includes(id))
                    root.urgentIds = [...root.urgentIds, id];
            }
        }

        function onFocusedWorkspaceChanged() {
            const id = Hyprland.focusedWorkspace?.id;
            if (id && root.urgentIds.includes(id))
                root.urgentIds = root.urgentIds.filter(w => w !== id);
        }
    }

    // Vertical slop only, via the wrapper (same pattern as ControlStatus): a
    // handler `margin` would extend sideways too.
    Item {
        anchors.fill: parent
        anchors.topMargin: -Appearance.sizes.barSlop
        anchors.bottomMargin: -Appearance.sizes.barSlop

        WheelDetent {
            // One workspace per notch: acting once per raw event meant a
            // single touchpad flick (a stream of tiny deltas) jumped several
            // workspaces.
            onStepped: steps => {
                for (let i = 0; i < Math.abs(steps); i++)
                    root.focusWorkspace(steps < 0 ? "m+1" : "m-1");
            }
        }
    }

    // ── Active pill (behind the slots) ──
    Rectangle {
        id: indicator

        readonly property Item activeItem: slots.count > 0 && root.focusedIdx >= 0 && root.focusedIdx < slots.count ? slots.itemAt(root.focusedIdx) : null
        readonly property real targetX: activeItem ? row.x + activeItem.x : 0
        readonly property real targetW: activeItem ? activeItem.width : 0

        property real leading: targetX
        property real trailing: targetX
        property real currentW: targetW

        visible: activeItem !== null
        x: Math.min(leading, trailing)
        width: Math.abs(leading - trailing) + currentW
        height: Appearance.sizes.barInner
        anchors.verticalCenter: parent.verticalCenter
        radius: Appearance.s(11)
        color: Theme.wsActiveBg

        Behavior on leading {
            Anim {
                curve: Appearance.anim.curves.emphasized
            }
        }

        Behavior on trailing {
            Anim {
                curve: Appearance.anim.curves.emphasized
                duration: Appearance.anim.durations.normal * 2
            }
        }

        Behavior on currentW {
            Anim {
                curve: Appearance.anim.curves.emphasized
            }
        }
    }

    Row {
        id: row

        x: 3
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        move: Transition {
            Anim {
                properties: "x"
                curve: Appearance.anim.curves.emphasized
            }
        }

        Repeater {
            id: slots

            model: Settings.workspaces

            WorkspaceSlot {
                bar: root
            }
        }
    }

    // ── Scratchpad chips ──
    // Special workspaces were invisible: focusing one blanked the active pill
    // and its windows appeared in no slot. A chip shows per special workspace
    // that has windows (or is currently up), hollow normally and filled while
    // it's on screen; click toggles it.
    Row {
        id: specials

        anchors.left: row.right
        anchors.leftMargin: Appearance.s(6)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Repeater {
            model: ScriptModel {
                values: root.rev >= 0 ? Hyprland.workspaces.values.filter(ws => ws.id < 0 && ((root.monitor?.lastIpcObject?.specialWorkspace?.name ?? "") === ws.name || Hyprland.toplevels.values.some(t => t.workspace?.id === ws.id))) : []
            }

            Item {
                id: chip

                required property var modelData

                readonly property var tops: root.rev >= 0 ? Hyprland.toplevels.values.filter(t => t.workspace?.id === chip.modelData.id) : []
                // The monitor's overlay slot, not the focused workspace: an
                // *empty* scratchpad is visible without ever taking focus.
                readonly property bool showing: (root.monitor?.lastIpcObject?.specialWorkspace?.name ?? "") === chip.modelData.name

                implicitWidth: tops.length > 0 ? Math.max(Appearance.sizes.barInner, chipIcons.implicitWidth + Appearance.s(12)) : Appearance.sizes.barInner
                implicitHeight: Appearance.sizes.barInner

                Behavior on implicitWidth {
                    Anim {
                        curve: Appearance.anim.curves.emphasized
                    }
                }

                // Hollow when parked (a place windows live, not where you
                // are), filled like the active pill while it's overlaying the
                // screen.
                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.s(11)
                    color: chip.showing ? Theme.wsActiveBg : "transparent"
                    border.width: chip.showing ? 0 : Math.max(1, Appearance.s(1.2))
                    border.color: Theme.barFgDim
                }

                StateLayer {
                    radius: Appearance.s(11)
                    hitSlop: Appearance.sizes.barSlop
                    onClicked: root.toggleSpecial(chip.modelData.name)
                }

                Row {
                    id: chipIcons

                    anchors.centerIn: parent
                    spacing: 2

                    Repeater {
                        model: ScriptModel {
                            values: chip.tops.slice(0, 3)
                        }

                        IconImage {
                            required property var modelData

                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: Appearance.sizes.wsIcon
                            asynchronous: true
                            source: Apps.toplevelIcon(modelData)
                        }
                    }
                }
            }
        }
    }
}
