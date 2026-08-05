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
    // The bar's own monitor, so each screen's row shows its own state.
    readonly property bool isActive: (bar.monitor?.activeWorkspace?.id ?? -1) === wsId
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
        hitSlop: Appearance.sizes.barSlop
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
        // wsUrgentFg on an urgent slot, not wsUrgentBg — which is the colour
        // of the fill *underneath* it, so an urgent empty workspace drew a
        // squircle outlined in its own background and read as a solid blob.
        border.color: slot.isActive ? Theme.wsActiveFg : slot.isUrgent ? Theme.wsUrgentFg : Theme.barFgDim

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

        // Three icons was presented as the whole story; a workspace holding
        // six windows deserves an honest row.
        StyledText {
            visible: slot.tops.length > 3
            anchors.verticalCenter: parent.verticalCenter
            text: `+${slot.tops.length - 3}`
            // Each pill states the colour its own fill was chosen to carry.
            // barFgDim is bar chrome and was being drawn on the urgent fill,
            // where it measured 1.34:1 in mocha; wsUrgentFg — defined by every
            // theme and until now read by none — clears 4.5:1 in all sixteen.
            color: slot.isActive ? Theme.wsActiveFg : slot.isUrgent ? Theme.wsUrgentFg : Theme.barFgDim
            font.pixelSize: Appearance.s(10)
            font.weight: Font.Bold
        }
    }
}
