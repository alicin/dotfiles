import QtQuick
import Quickshell.Services.UPower
import qs.config
import qs.components
import qs.services

// Horizontal battery (drawn, not a glyph) + percentage, with the current CPU
// power profile as a small glyph to its left. Green while charging/full, red
// when low. Click opens the power-profile menu.
Item {
    id: root

    property var popouts: null

    readonly property var device: UPower.displayDevice
    readonly property real pct: device?.percentage ?? 0
    readonly property bool charging: (device?.state ?? 0) === UPowerDeviceState.Charging
    readonly property bool full: (device?.state ?? 0) === UPowerDeviceState.FullyCharged
    readonly property color tint: charging || full ? Theme.barOk : !charging && pct <= 0.15 ? Theme.barUrgent : Theme.barFg

    // Colour-coded rather than plain white: the profile glyph sits next to a
    // battery, and "which way is this costing me" is the thing you actually
    // want to read off it at a glance.
    readonly property color profileTint: Power.profile === PowerProfile.Performance ? Theme.barWarn : Power.profile === PowerProfile.PowerSaver ? Theme.barOk : Theme.barFg

    visible: device?.isLaptopBattery ?? false
    implicitWidth: content.implicitWidth + Appearance.sizes.modulePad
    implicitHeight: Appearance.sizes.barInner

    StateLayer {
        onClicked: root.popouts?.toggle("battery", root)
    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: Appearance.s(6)

        // Deliberately smaller than the battery beside it: this is a modifier
        // on the reading, not a second reading.
        FIcon {
            anchors.verticalCenter: parent.verticalCenter
            icon: Power.glyph(Power.profile)
            font.pixelSize: Appearance.s(14)
            color: root.profileTint
        }

        Item {
            readonly property int bodyW: Appearance.s(21)
            readonly property int bodyH: Appearance.s(11)

            anchors.verticalCenter: parent.verticalCenter
            width: bodyW + Appearance.s(3)
            height: bodyH

            Rectangle {
                id: body

                width: parent.bodyW
                height: parent.bodyH
                radius: Appearance.s(3)
                color: "transparent"
                border.width: Math.max(1, Appearance.s(1.4))
                border.color: root.tint

                Behavior on border.color {
                    CAnim {}
                }

                Rectangle {
                    readonly property int inset: Appearance.s(2.5)

                    x: inset
                    y: inset
                    height: parent.height - inset * 2
                    width: Math.max(root.pct > 0.03 ? Appearance.s(2) : 0, (parent.width - inset * 2) * root.pct)
                    radius: Appearance.s(1.5)
                    color: root.tint

                    Behavior on width {
                        Anim {}
                    }

                    Behavior on color {
                        CAnim {}
                    }
                }

                FIcon {
                    visible: root.charging
                    anchors.centerIn: parent
                    icon: "bolt_fill"
                    font.pixelSize: Appearance.s(9)
                    color: Theme.accentFg
                }
            }

            Rectangle {
                anchors.left: body.right
                anchors.leftMargin: Appearance.s(1)
                anchors.verticalCenter: body.verticalCenter
                width: Appearance.s(2.5)
                height: Appearance.s(5)
                radius: Appearance.s(1)
                color: root.tint

                Behavior on color {
                    CAnim {}
                }
            }
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: `${Math.round(root.pct * 100)}%`
            color: root.tint
            font.weight: Font.Bold
        }
    }
}
