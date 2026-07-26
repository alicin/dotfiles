import QtQuick
import Quickshell.Hyprland
import qs.config
import qs.components

// Fixed row of workspaces (count from settings.json): empty ones are hollow
// circles, populated ones show their apps' icons. The focused workspace gets
// a pill that slides *and stretches* between slots — leading edge fast,
// trailing edge slow, both on the M3 emphasized curve (caelestia's
// ActiveIndicator, turned horizontal).
Item {
    id: root

    // Hyprland.toplevels.values doesn't re-notify when an existing window
    // hops workspaces, so bump a revision counter from raw IPC events and
    // reference it in the occupancy bindings.
    property int rev: 0
    property list<int> urgentIds: []

    readonly property int focusedIdx: (Hyprland.focusedWorkspace?.id ?? 1) - 1

    function focusWorkspace(ws: string): void {
        Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.focus({ workspace = "${ws}" })` : `workspace ${ws}`);
    }

    implicitWidth: row.implicitWidth + 6
    implicitHeight: Appearance.sizes.barInner

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            const n = event.name;
            if (n === "openwindow" || n === "closewindow" || n === "movewindowv2" || n === "movewindow") {
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

    WheelHandler {
        onWheel: event => root.focusWorkspace(event.angleDelta.y < 0 ? "m+1" : "m-1")
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
}
