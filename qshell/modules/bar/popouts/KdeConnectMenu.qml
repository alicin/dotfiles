import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// Paired devices with battery/network state and the quick actions worth having
// in a dropdown — ring, ping, push the clipboard. Anything richer (files, SMS,
// remote input) is what the full KDE Connect app is for.
Column {
    id: root

    function glyphFor(type: string): string {
        if (type === "tablet")
            return "device_tablet_portrait";
        if (type === "desktop" || type === "laptop")
            return "desktopcomputer";
        return "device_phone_portrait";
    }

    function subtitle(d: var): string {
        if (!d.reachable)
            return "not reachable";
        const bits = [];
        if (d.battery >= 0)
            bits.push(`${d.battery}%${d.charging ? " · charging" : ""}`);
        if (d.network)
            bits.push(d.network);
        return bits.length ? bits.join(" · ") : "connected";
    }

    width: Appearance.s(330)
    spacing: Appearance.s(2)

    Component.onCompleted: KdeConnect.refresh()

    Item {
        width: parent.width
        height: Appearance.sizes.menuRowHeight

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: "KDE Connect"
            color: Theme.surfaceFg
        }

        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: openLabel.implicitWidth + Appearance.s(20)
            implicitHeight: Appearance.s(26)
            radius: height / 2
            color: Theme.surfaceHoverBg

            StateLayer {
                radius: parent.radius
                color: Theme.surfaceFg
                onClicked: KdeConnect.openApp()
            }

            StyledText {
                id: openLabel

                anchors.centerIn: parent
                text: "Open app"
                color: Theme.surfaceFg
                font.pixelSize: Appearance.font.size.small
            }
        }
    }

    MenuSeparator {
        width: parent.width
    }

    StyledText {
        visible: KdeConnect.devices.length === 0
        height: Appearance.sizes.menuRowHeight
        text: "No paired devices"
        color: Theme.surfaceFgDim
    }

    Repeater {
        model: ScriptModel {
            values: KdeConnect.devices
        }

        Item {
            id: devItem

            required property var modelData

            width: parent.width
            height: Appearance.s(52)

            FIcon {
                id: devGlyph

                x: Appearance.s(8)
                anchors.verticalCenter: parent.verticalCenter
                icon: root.glyphFor(devItem.modelData.type)
                color: devItem.modelData.reachable ? Theme.accent : Theme.surfaceFgDim
            }

            Column {
                anchors.left: devGlyph.right
                anchors.leftMargin: Appearance.s(10)
                anchors.right: actions.left
                anchors.rightMargin: Appearance.s(8)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.s(1)

                StyledText {
                    width: parent.width
                    text: devItem.modelData.name
                    color: Theme.surfaceFg
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    text: root.subtitle(devItem.modelData)
                    color: Theme.surfaceFgDim
                    font.pixelSize: Appearance.font.size.small
                    font.weight: Font.Normal
                    elide: Text.ElideRight
                }
            }

            Row {
                id: actions

                anchors.right: parent.right
                anchors.rightMargin: Appearance.s(6)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.s(2)
                visible: devItem.modelData.reachable

                Repeater {
                    model: [
                        {
                            glyph: "bell_fill",
                            act: "ring"
                        },
                        {
                            glyph: "paperplane_fill",
                            act: "ping"
                        },
                        {
                            glyph: "doc_on_clipboard",
                            act: "clip"
                        }
                    ]

                    Item {
                        id: actBtn

                        required property var modelData

                        width: Appearance.s(30)
                        height: Appearance.s(30)

                        StateLayer {
                            radius: width / 2
                            color: Theme.surfaceFg
                            onClicked: {
                                const id = devItem.modelData.id;
                                if (actBtn.modelData.act === "ring")
                                    KdeConnect.ring(id);
                                else if (actBtn.modelData.act === "ping")
                                    KdeConnect.ping(id);
                                else
                                    KdeConnect.sendClipboard(id);
                            }
                        }

                        FIcon {
                            anchors.centerIn: parent
                            icon: actBtn.modelData.glyph
                            font.pixelSize: Appearance.font.size.normal
                            color: Theme.surfaceFg
                        }
                    }
                }
            }
        }
    }
}
