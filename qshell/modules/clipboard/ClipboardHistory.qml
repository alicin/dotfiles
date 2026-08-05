import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

// Clipboard history picker — deliberately the same panel as the app launcher
// (same width, radius, item height, spring-up curve and gliding highlight), so
// Super+D and Super+Shift+V feel like one surface with two sources. Replaces
// the `cliphist list | wofi --show dmenu` binding.
Scope {
    id: root

    property bool open: false

    // Pinned by NAME, not by object — see the launcher's identical pin for
    // what a severed screen binding costs when a monitor comes and goes.
    property string pinned: ""

    onOpenChanged: {
        // The OSD shares this panel's bottom-center spot.
        Osd.clipboardOpen = open;
        if (open) {
            root.pinned = Hyprland.focusedMonitor?.name ?? "";
            if (Osd.kind !== "countdown")
                Osd.hide();
            Clipboard.refresh();
            field.text = "";
            list.currentIndex = 0;
            field.forceActiveFocus();
        }
    }

    function copyCurrent(): void {
        const item = list.currentItem;
        if (item) {
            Clipboard.copy(item.modelData.id);
            root.open = false;
        }
    }

    function removeCurrent(): void {
        const item = list.currentItem;
        if (!item)
            return;
        const at = list.currentIndex;
        Clipboard.remove(item.modelData.id);
        list.currentIndex = Math.min(at, list.count - 1);
    }

    IpcHandler {
        target: "clipboard"

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

        screen: Quickshell.screens.find(s => s.name === (root.pinned || Hyprland.focusedMonitor?.name)) ?? Quickshell.screens[0] ?? null
        color: "transparent"
        implicitWidth: Appearance.sizes.launcherWidth + Appearance.s(40)
        // Tall enough for the full 8-row panel PLUS the floating image
        // preview above it — at s(700) the preview clipped at the window's
        // top edge. Free: the surface is transparent and the input mask
        // covers only the panel.
        implicitHeight: Appearance.s(1000)

        anchors {
            bottom: true
        }

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        WlrLayershell.namespace: "qshell:clipboard"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

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

        // Enlarged look at the highlighted image entry — the 58px row thumbs
        // are indistinguishable after a screenshot session, and picking the
        // wrong one means pasting the wrong one. Purely visual (outside the
        // input mask), floating above the panel.
        Rectangle {
            visible: root.open && (list.currentItem?.showsThumb ?? false) && preview.status === Image.Ready
            anchors.horizontalCenter: parent.horizontalCenter
            y: panel.y - height - Appearance.s(10)
            width: preview.paintedWidth + Appearance.s(16)
            height: preview.paintedHeight + Appearance.s(16)
            radius: Appearance.s(12)
            color: Theme.surfaceBg
            border.width: 1
            border.color: Theme.surfaceBorder
            opacity: panel.opacity

            Image {
                id: preview

                anchors.centerIn: parent
                width: Appearance.s(420)
                height: Appearance.s(260)
                source: list.currentItem?.thumbSource ?? ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
                sourceSize.width: Appearance.s(840)
            }
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
                    // Blank until the first listing lands — flashing
                    // "Clipboard is empty" for the round trip read as data
                    // loss for a beat.
                    text: field.text ? "No matches" : Clipboard.loaded ? "Clipboard is empty" : ""
                    color: Theme.surfaceFgDim
                }

                ListView {
                    id: list

                    model: ScriptModel {
                        values: Clipboard.search(field.text)
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

                    delegate: ClipItem {
                        onActivated: root.open = false
                        // The model reset yanked the highlight to the top on
                        // every hover-× delete — stay where the user was.
                        onRemoved: at => list.currentIndex = Math.min(at, list.count - 1)
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

                    onAccepted: root.copyCurrent()
                    Keys.onUpPressed: list.currentIndex = Math.max(0, list.currentIndex - 1)
                    Keys.onDownPressed: list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1)
                    Keys.onEscapePressed: root.open = false
                    // Shift+Delete drops an entry — plain Delete has to stay
                    // available for editing the query.
                    Keys.onDeletePressed: event => {
                        if (event.modifiers & Qt.ShiftModifier)
                            root.removeCurrent();
                        else
                            event.accepted = false;
                    }

                    StyledText {
                        visible: !field.text
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search clipboard…"
                        color: Theme.surfaceFgDim
                    }
                }
            }
        }
    }
}
