import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// KDE Connect page: one card per paired device with battery, cell signal and
// the actions worth having without switching windows. Anything richer (files,
// SMS, remote input) is what the full app is for — hence the header button.
//
// The actions are labelled chips rather than the bare icon buttons this had as
// a dropdown: "ring the phone" and "push my clipboard to it" are not things
// you want to guess at from a glyph.
Column {
    id: root

    signal back

    function glyphFor(type: string): string {
        if (type === "tablet")
            return "device_tablet_portrait";
        if (type === "desktop" || type === "laptop")
            return "desktopcomputer";
        return "device_phone_portrait";
    }

    spacing: Appearance.s(8)

    Component.onCompleted: KdeConnect.refresh()

    // Four rising bars, filled to `bars` (0-4). -1 means the connectivity
    // plugin isn't reporting, and the whole thing hides.
    component SignalBars: Row {
        id: sig

        property int bars: -1

        visible: bars >= 0
        spacing: Appearance.s(2)

        Repeater {
            model: 4

            Rectangle {
                required property int index

                width: Appearance.s(3)
                height: Appearance.s(4) + index * Appearance.s(2)
                anchors.bottom: parent.bottom
                radius: width / 2
                color: index < sig.bars ? Theme.surfaceFg : Qt.alpha(Theme.surfaceFg, 0.22)

                Behavior on color {
                    CAnim {}
                }
            }
        }
    }

    PageHeader {
        title: "KDE Connect"
        onBack: root.back()

        Chip {
            anchors.verticalCenter: parent.verticalCenter
            label: "Refresh"
            glyph: "arrow_clockwise"
            onTapped: KdeConnect.refresh()
        }

        Chip {
            anchors.verticalCenter: parent.verticalCenter
            label: "Open app"
            onTapped: KdeConnect.openApp()
        }
    }

    Card {
        visible: KdeConnect.devices.length === 0

        StyledText {
            x: Appearance.s(12)
            height: Appearance.s(30)
            text: "No paired devices"
            color: Theme.surfaceFgDim
            font.pixelSize: Appearance.font.size.small
            font.weight: Font.Normal
        }

        StyledText {
            x: Appearance.s(12)
            width: parent.width - Appearance.s(24)
            text: "Pair one from the app — the daemon has to be running on both ends."
            color: Theme.surfaceFgDim
            font.pixelSize: Appearance.font.size.small
            font.weight: Font.Normal
            wrapMode: Text.WordWrap
        }
    }

    Repeater {
        model: ScriptModel {
            values: KdeConnect.devices
        }

        Card {
            id: devCard

            required property var modelData

            readonly property bool up: modelData.reachable
            readonly property bool hasBattery: modelData.battery >= 0

            // ── Identity ──
            Item {
                width: parent.width
                height: Appearance.s(40)

                Badge {
                    id: devBadge

                    x: Appearance.s(8)
                    anchors.verticalCenter: parent.verticalCenter
                    size: Appearance.s(30)
                    glyph: root.glyphFor(devCard.modelData.type)
                    active: devCard.up
                }

                StyledText {
                    anchors.left: devBadge.right
                    anchors.leftMargin: Appearance.s(10)
                    anchors.right: netInfo.left
                    anchors.rightMargin: Appearance.s(8)
                    anchors.verticalCenter: parent.verticalCenter
                    text: devCard.modelData.name
                    color: devCard.up ? Theme.surfaceFg : Theme.surfaceFgDim
                    elide: Text.ElideRight
                }

                Row {
                    id: netInfo

                    anchors.right: parent.right
                    anchors.rightMargin: Appearance.s(12)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.s(6)

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: text !== ""
                        text: devCard.up ? devCard.modelData.network : "Not reachable"
                        color: Theme.surfaceFgDim
                        font.pixelSize: Appearance.font.size.small
                        font.weight: Font.Normal
                    }

                    SignalBars {
                        anchors.verticalCenter: parent.verticalCenter
                        bars: devCard.up ? devCard.modelData.signal : -1
                    }
                }
            }

            // ── Battery ──
            Item {
                width: parent.width
                height: devCard.hasBattery ? Appearance.s(26) : 0
                visible: devCard.hasBattery

                Rectangle {
                    id: battTrack

                    anchors.left: parent.left
                    anchors.leftMargin: Appearance.s(12)
                    anchors.right: battLabel.left
                    anchors.rightMargin: Appearance.s(10)
                    anchors.verticalCenter: parent.verticalCenter
                    height: Appearance.s(6)
                    radius: height / 2
                    color: Qt.alpha(Theme.surfaceFg, 0.16)

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, devCard.modelData.battery / 100))
                        height: parent.height
                        radius: parent.radius
                        color: devCard.modelData.charging ? Theme.ok : devCard.modelData.battery <= 20 ? Theme.urgent : Theme.accent

                        Behavior on width {
                            Anim {
                                duration: Appearance.anim.durations.small
                            }
                        }

                        Behavior on color {
                            CAnim {}
                        }
                    }
                }

                StyledText {
                    id: battLabel

                    anchors.right: parent.right
                    anchors.rightMargin: Appearance.s(12)
                    anchors.verticalCenter: parent.verticalCenter
                    text: `${devCard.modelData.battery}%${devCard.modelData.charging ? " ⚡" : ""}`
                    color: Theme.surfaceFgDim
                    font.pixelSize: Appearance.font.size.small
                }
            }

            // ── Actions ──
            Row {
                x: Appearance.s(12)
                height: visible ? Appearance.s(36) : 0
                visible: devCard.up
                spacing: Appearance.s(6)

                // Each acknowledges with a green flash — "Send clipboard" in
                // particular is invisible on both ends from where you sit.
                Chip {
                    anchors.verticalCenter: parent.verticalCenter
                    label: "Ring"
                    glyph: "bell_fill"
                    onTapped: {
                        KdeConnect.ring(devCard.modelData.id);
                        flash("Ringing");
                    }
                }

                Chip {
                    anchors.verticalCenter: parent.verticalCenter
                    label: "Ping"
                    glyph: "paperplane_fill"
                    onTapped: {
                        KdeConnect.ping(devCard.modelData.id);
                        flash("Sent");
                    }
                }

                Chip {
                    anchors.verticalCenter: parent.verticalCenter
                    label: "Send clipboard"
                    glyph: "doc_on_clipboard"
                    onTapped: {
                        KdeConnect.sendClipboard(devCard.modelData.id);
                        flash("Sent");
                    }
                }
            }
        }
    }
}
