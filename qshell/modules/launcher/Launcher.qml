import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

// App launcher in the caelestia style: a rounded panel that springs up from
// the bottom of the focused screen (M3 expressive default-spatial curve),
// fuzzy search at the bottom, results above with a gliding selection
// highlight. Toggle with `qs -c qshell ipc call launcher toggle`.
Scope {
    id: root

    property bool open: false

    onOpenChanged: {
        if (open) {
            field.text = "";
            list.currentIndex = 0;
            field.forceActiveFocus();
        }
    }

    function launchCurrent(): void {
        const item = list.currentItem;
        if (item) {
            Apps.launch(item.modelData);
            root.open = false;
        }
    }

    IpcHandler {
        target: "launcher"

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

    PanelWindow {
        id: win

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null
        color: "transparent"
        implicitWidth: Appearance.sizes.launcherWidth + Appearance.s(40)
        implicitHeight: Appearance.s(700)

        anchors {
            bottom: true
        }

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        WlrLayershell.namespace: "qshell:launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        // Input only lands on the panel while it's open; otherwise the
        // (permanently mapped, invisible) window is click-through.
        mask: Region {
            item: root.open ? panel : null
        }

        HyprlandFocusGrab {
            active: root.open
            windows: [win]
            onCleared: root.open = false
        }

        Elevation {
            anchors.fill: panel
            radius: panel.radius
            level: 4
            visible: panel.visible
            opacity: panel.opacity
        }

        Rectangle {
            id: panel

            property real offsetScale: root.open ? 0 : 1

            readonly property int pad: Appearance.s(12)

            visible: offsetScale < 1
            opacity: 1 - offsetScale
            y: win.height - (height + Appearance.s(14)) * (1 - offsetScale)
            anchors.horizontalCenter: parent.horizontalCenter

            width: Appearance.sizes.launcherWidth
            height: pad + listArea.height + Appearance.s(8) + searchBg.height + pad
            radius: Appearance.sizes.launcherRadius
            color: Theme.surfaceBg
            border.width: 1
            border.color: Theme.surfaceBorder

            Behavior on offsetScale {
                Anim {
                    curve: Appearance.anim.curves.expressiveDefaultSpatial
                    duration: Appearance.anim.durations.expressiveDefaultSpatial
                }
            }

            Item {
                id: listArea

                x: panel.pad
                y: panel.pad
                width: panel.width - panel.pad * 2
                height: list.count > 0 ? list.height : empty.height

                StyledText {
                    id: empty

                    visible: list.count === 0
                    height: Appearance.s(40)
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No matches"
                    color: Theme.surfaceFgDim
                }

                ListView {
                    id: list

                    model: ScriptModel {
                        values: Apps.search(field.text)
                        onValuesChanged: list.currentIndex = 0
                    }

                    width: parent.width
                    height: Math.min(count, Settings.launcherMaxShown) * (Appearance.sizes.launcherItemHeight + spacing) - (count > 0 ? spacing : 0)
                    spacing: Appearance.s(4)
                    clip: true

                    preferredHighlightBegin: 0
                    preferredHighlightEnd: height
                    highlightRangeMode: ListView.ApplyRange

                    highlightFollowsCurrentItem: false
                    highlight: Rectangle {
                        radius: Appearance.s(16)
                        color: Theme.surfaceHoverBg
                        width: list.width
                        height: list.currentItem?.height ?? 0
                        y: list.currentItem?.y ?? 0

                        Behavior on y {
                            Anim {
                                curve: Appearance.anim.curves.expressiveDefaultSpatial
                                duration: Appearance.anim.durations.expressiveDefaultSpatial
                            }
                        }
                    }

                    delegate: AppItem {
                        onActivated: root.open = false
                    }

                    WheelScroll {
                        view: list
                    }
                }
            }

            Rectangle {
                id: searchBg

                x: panel.pad
                width: panel.width - panel.pad * 2
                height: Appearance.s(44)
                anchors.bottom: parent.bottom
                anchors.bottomMargin: panel.pad
                radius: height / 2
                color: Theme.surfaceHoverBg

                FIcon {
                    id: searchIcon

                    anchors.left: parent.left
                    anchors.leftMargin: Appearance.s(16)
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "search"
                    color: Theme.surfaceFgDim
                }

                TextInput {
                    id: field

                    anchors.left: searchIcon.right
                    anchors.leftMargin: Appearance.s(10)
                    anchors.right: parent.right
                    anchors.rightMargin: Appearance.s(16)
                    anchors.verticalCenter: parent.verticalCenter

                    color: Theme.surfaceFg
                    font.family: Appearance.font.family
                    font.pixelSize: Appearance.font.size.normal
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentFg
                    clip: true

                    onAccepted: root.launchCurrent()
                    Keys.onUpPressed: list.currentIndex = Math.max(0, list.currentIndex - 1)
                    Keys.onDownPressed: list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1)
                    Keys.onEscapePressed: root.open = false

                    StyledText {
                        visible: !field.text
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search apps…"
                        color: Theme.surfaceFgDim
                    }
                }
            }
        }
    }
}
