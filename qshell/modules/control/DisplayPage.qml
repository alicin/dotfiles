import QtQuick
import qs.config
import qs.components
import qs.services

// Displays: the three layout presets that used to be Super+Ctrl+M/E/L, one row
// per output with its mode, and the eDP toggle — which is worth having a
// labelled button because doing it by keybind and getting it wrong leaves you
// looking at a black laptop panel.
Column {
    id: root

    signal back

    spacing: Appearance.s(8)

    Component.onCompleted: Displays.polling = true
    Component.onDestruction: Displays.polling = false

    PageHeader {
        title: "Displays"
        onBack: root.back()
    }

    // ── Layouts ──
    Card {
        title: "Layout"

        // Inset to the card's own grid — 6 on the left where the output
        // badges start, 8 on the right where their switches end. A Card pads
        // vertically but not horizontally, so full-width content otherwise
        // lands flush against the tint's rounded edge.
        Row {
            x: Appearance.s(6)
            width: parent.width - Appearance.s(14)
            spacing: Appearance.s(6)

            component LayoutChip: Rectangle {
                id: chip

                property string label: ""
                property string glyph: ""

                signal tapped

                width: (parent.width - Appearance.s(12)) / 3
                height: Appearance.s(52)
                radius: Appearance.s(12)
                color: Qt.alpha(Theme.surfaceFg, 0.1)

                StateLayer {
                    radius: chip.radius
                    color: Theme.surfaceFg
                    onClicked: chip.tapped()
                }

                Column {
                    anchors.centerIn: parent
                    spacing: Appearance.s(3)

                    FIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        icon: chip.glyph
                        font.pixelSize: Appearance.s(16)
                        color: Theme.surfaceFg
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: chip.label
                        color: Theme.surfaceFgDim
                        font.pixelSize: Appearance.font.size.small
                    }
                }
            }

            LayoutChip {
                glyph: "arrow_2_circlepath"
                label: "Auto"
                onTapped: Displays.applyLayout("auto")
            }

            LayoutChip {
                glyph: "device_desktop"
                label: "External"
                onTapped: Displays.applyLayout("setup-external")
            }

            LayoutChip {
                glyph: "device_laptop"
                label: "Laptop"
                onTapped: Displays.applyLayout("setup-laptop")
            }
        }
    }

    // ── Outputs ──
    Card {
        title: "Outputs"

        Repeater {
            model: Displays.monitors

            Item {
                id: monRow

                required property var modelData

                // The last output standing can't be switched off — that is the
                // state with no way back that isn't a keybind you can't read.
                readonly property bool lastOne: !modelData.disabled && Displays.active.length <= 1

                width: parent.width
                height: Appearance.s(46)

                Badge {
                    id: monBadge

                    x: Appearance.s(6)
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: /^eDP/i.test(monRow.modelData.name) ? "device_laptop" : "device_desktop"
                    active: !monRow.modelData.disabled
                    size: Appearance.s(30)
                }

                Column {
                    anchors.left: monBadge.right
                    anchors.leftMargin: Appearance.s(10)
                    anchors.right: monSwitch.left
                    anchors.rightMargin: Appearance.s(8)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    StyledText {
                        width: parent.width
                        text: monRow.modelData.name + (monRow.modelData.focused ? " · focused" : "")
                        color: Theme.surfaceFg
                        font.pixelSize: Appearance.font.size.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        width: parent.width
                        text: monRow.modelData.disabled ? "Disabled" : `${monRow.modelData.width}×${monRow.modelData.height} @ ${monRow.modelData.refresh}Hz · ${monRow.modelData.scale}×`
                        color: Theme.surfaceFgDim
                        font.pixelSize: Appearance.font.size.small
                        font.weight: Font.Normal
                        elide: Text.ElideRight
                    }
                }

                StyledSwitch {
                    id: monSwitch

                    anchors.right: parent.right
                    anchors.rightMargin: Appearance.s(8)
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: monRow.lastOne ? 0.4 : 1
                    checked: !monRow.modelData.disabled
                    onToggled: on => {
                        if (!monRow.lastOne)
                            Displays.setEnabled(monRow.modelData, on);
                    }
                }
            }
        }

        StyledText {
            visible: Displays.monitors.length === 0
            height: Appearance.s(36)
            text: "No outputs reported"
            color: Theme.surfaceFgDim
            font.pixelSize: Appearance.font.size.small
        }
    }

    // ── The eDP toggle ──
    // Its own row rather than a fourth layout chip: it saves and restores the
    // panel's exact mode/position/scale, which the presets don't, and it is
    // the one control here with a documented way to strand you.
    Card {
        title: "Laptop panel"

        Item {
            width: parent.width
            height: Appearance.s(40)

            Chip {
                id: edpChip

                anchors.left: parent.left
                anchors.leftMargin: Appearance.s(6)
                anchors.verticalCenter: parent.verticalCenter
                label: "Toggle eDP-1"
                glyph: "device_laptop"
                onTapped: {
                    Displays.toggleEdp();
                    edpChip.flash("Toggling");
                }
            }

            StyledText {
                anchors.left: edpChip.right
                anchors.leftMargin: Appearance.s(10)
                anchors.right: parent.right
                anchors.rightMargin: Appearance.s(8)
                anchors.verticalCenter: parent.verticalCenter
                // Short enough to survive the width the chip leaves it — the
                // full sentence elided to "…a stuck …", which is worse than
                // saying less. The card title supplies what "it" is.
                text: "Super+Shift+O relights it"
                color: Theme.surfaceFgDim
                font.pixelSize: Appearance.font.size.small
                font.weight: Font.Normal
                elide: Text.ElideRight
            }
        }
    }
}
