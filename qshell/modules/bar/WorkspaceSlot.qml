import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

Item {
    id: slot

    required property var bar
    required property int index

    readonly property int wsId: index + 1
    readonly property var tops: bar.rev >= 0 ? Hyprland.toplevels.values.filter(t => t.workspace?.id === slot.wsId) : []
    readonly property bool occupied: tops.length > 0
    readonly property bool isActive: (Hyprland.focusedWorkspace?.id ?? -1) === wsId
    readonly property bool isUrgent: bar.urgentIds.includes(wsId)

    // 1:1 slot by default (width == bar inner height); grows only when the
    // app icons genuinely need more room.
    implicitWidth: occupied ? Math.max(Appearance.sizes.barInner, iconRow.implicitWidth + Appearance.s(12)) : Appearance.sizes.barInner
    implicitHeight: Appearance.sizes.barInner

    Behavior on implicitWidth {
        Anim {
            curve: Appearance.anim.curves.emphasized
        }
    }

    StateLayer {
        radius: Appearance.s(11)
        onClicked: slot.bar.focusWorkspace(slot.wsId.toString())
    }

    // Urgent tint (the active pill covers it once focused, which also clears it).
    Rectangle {
        anchors.fill: parent
        radius: Appearance.s(11)
        color: Theme.wsUrgentBg
        opacity: slot.isUrgent && !slot.isActive ? 0.9 : 0

        Behavior on opacity {
            Anim {
                curve: Appearance.anim.curves.expressiveDefaultEffects
                duration: Appearance.anim.durations.expressiveDefaultEffects
            }
        }
    }

    // Empty workspace: hollow squircle — never filled; focus/urgency only
    // recolor the border.
    Rectangle {
        anchors.centerIn: parent
        visible: !slot.occupied
        width: Appearance.sizes.wsDot
        height: width
        radius: width * 0.38
        color: "transparent"
        border.width: 2.5
        border.color: slot.isActive ? Theme.wsActiveFg : slot.isUrgent ? Theme.wsUrgentBg : Theme.barFgDim

        Behavior on border.color {
            CAnim {}
        }
    }

    // Populated workspace: app icons.
    Row {
        id: iconRow

        anchors.centerIn: parent
        visible: slot.occupied
        spacing: 2

        add: Transition {
            Anim {
                properties: "scale"
                from: 0
                to: 1
                curve: Appearance.anim.curves.standardDecel
            }
        }

        move: Transition {
            Anim {
                properties: "x"
            }
        }

        Repeater {
            model: ScriptModel {
                values: slot.tops.slice(0, 3)
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
