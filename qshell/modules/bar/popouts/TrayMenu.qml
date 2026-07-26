import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config
import qs.components

// Custom-drawn DBus menu for a tray item (one submenu level, expanded inline).
Column {
    id: root

    property SystemTrayItem item: null
    property var popouts: null
    property var expandedEntry: null

    width: Appearance.s(240)
    spacing: 0

    QsMenuOpener {
        id: opener

        menu: root.item?.menu ?? null
    }

    StyledText {
        visible: (opener.children?.values.length ?? 0) === 0
        height: Appearance.sizes.menuRowHeight
        text: root.item?.title || "No menu"
        color: Theme.surfaceFgDim
    }

    Repeater {
        model: opener.children

        Column {
            id: entryItem

            required property var modelData

            width: parent.width

            MenuSeparator {
                visible: entryItem.modelData.isSeparator
                width: parent.width
            }

            Item {
                visible: !entryItem.modelData.isSeparator
                width: parent.width
                height: Appearance.s(34)

                StateLayer {
                    enabled: entryItem.modelData.enabled
                    radius: Appearance.rounding.normal
                    color: Theme.surfaceFg
                    onClicked: {
                        if (entryItem.modelData.hasChildren) {
                            root.expandedEntry = root.expandedEntry === entryItem.modelData ? null : entryItem.modelData;
                        } else {
                            entryItem.modelData.triggered();
                            root.popouts?.close();
                        }
                    }
                }

                FIcon {
                    id: checkGlyph

                    x: Appearance.s(8)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: entryItem.modelData.checkState !== Qt.Unchecked
                    icon: entryItem.modelData.checkState === Qt.Checked ? "checkmark_alt" : "minus"
                    color: Theme.accent
                    font.pixelSize: Appearance.font.size.small
                }

                IconImage {
                    id: entryIcon

                    x: Appearance.s(8)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !checkGlyph.visible && entryItem.modelData.icon !== ""
                    implicitSize: Appearance.s(14)
                    source: entryItem.modelData.icon
                }

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: (checkGlyph.visible || entryIcon.visible) ? Appearance.s(28) : Appearance.s(10)
                    anchors.right: chevron.visible ? chevron.left : parent.right
                    anchors.rightMargin: Appearance.s(8)
                    anchors.verticalCenter: parent.verticalCenter
                    text: entryItem.modelData.text || "…"
                    color: entryItem.modelData.enabled ? Theme.surfaceFg : Theme.surfaceFgDim
                    font.pixelSize: Appearance.font.size.small
                    elide: Text.ElideRight
                }

                FIcon {
                    id: chevron

                    anchors.right: parent.right
                    anchors.rightMargin: Appearance.s(10)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: entryItem.modelData.hasChildren
                    icon: root.expandedEntry === entryItem.modelData ? "chevron_up" : "chevron_down"
                    color: Theme.surfaceFgDim
                    font.pixelSize: Appearance.font.size.small
                }
            }

            // One inline submenu level.
            Loader {
                active: root.expandedEntry === entryItem.modelData
                visible: active

                sourceComponent: Column {
                    width: root.width

                    QsMenuOpener {
                        id: subOpener

                        menu: entryItem.modelData
                    }

                    Repeater {
                        model: subOpener.children

                        Item {
                            id: subItem

                            required property var modelData

                            width: parent.width
                            height: subItem.modelData.isSeparator ? Appearance.s(8) : Appearance.s(30)

                            MenuSeparator {
                                visible: subItem.modelData.isSeparator
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - Appearance.s(24)
                                x: Appearance.s(20)
                            }

                            StateLayer {
                                visible: !subItem.modelData.isSeparator
                                enabled: subItem.modelData.enabled
                                radius: Appearance.rounding.normal
                                color: Theme.surfaceFg
                                onClicked: {
                                    subItem.modelData.triggered();
                                    root.popouts?.close();
                                }
                            }

                            StyledText {
                                visible: !subItem.modelData.isSeparator
                                anchors.left: parent.left
                                anchors.leftMargin: Appearance.s(24)
                                anchors.right: parent.right
                                anchors.rightMargin: Appearance.s(8)
                                anchors.verticalCenter: parent.verticalCenter
                                text: subItem.modelData.text || "…"
                                color: subItem.modelData.enabled ? Theme.surfaceFg : Theme.surfaceFgDim
                                font.pixelSize: Appearance.font.size.small
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
