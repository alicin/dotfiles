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

    // The screen this panel is pinned to, by NAME. Pinning used to be an
    // assignment to win.screen, which severs the binding — and a ShellScreen
    // object does not survive monitor churn (an unplug, an eDP toggle, a
    // `hyprctl reload`). Once the latched one died the window had no screen
    // and never mapped again: the launcher and the clipboard picker both
    // silently stopped opening, with working IPC, until the shell restarted.
    // A name outlives the object, and the binding re-resolves.
    property string pinned: ""

    onOpenChanged: {
        // The OSD shares this panel's bottom-center spot.
        Osd.launcherOpen = open;
        if (open) {
            // Pinned per open: with focus-follows-mouse, an open panel used to
            // remap to the other monitor the moment the cursor crossed.
            root.pinned = Hyprland.focusedMonitor?.name ?? "";
            if (Osd.kind !== "countdown")
                Osd.hide();
            field.text = "";
            list.currentIndex = 0;
            list.lastHoverPos = Qt.point(-1e9, -1e9);
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

        screen: Quickshell.screens.find(s => s.name === (root.pinned || Hyprland.focusedMonitor?.name)) ?? Quickshell.screens[0] ?? null
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
            // The launch that closed the panel defers its frecency
            // bookkeeping until the panel is gone — flushing earlier re-sorts
            // the list mid-fade.
            onVisibleChanged: {
                if (!visible)
                    Apps.flushUsage();
            }
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

            // The panel breathes between result counts instead of snapping
            // its top edge on every keystroke.
            Behavior on height {
                enabled: root.open

                Anim {
                    curve: Appearance.anim.curves.standardDecel
                    duration: Appearance.anim.durations.expressiveDefaultEffects
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

                    // Where hover last reported the cursor in window coords —
                    // AppItem's hover-select filter (see its comment).
                    property point lastHoverPos: Qt.point(-1e9, -1e9)

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
                        query: field.text
                        onActivated: root.open = false
                    }

                    WheelScroll {
                        view: list
                    }

                    // Thin scroll indicator — result 9+ used to exist behind
                    // the clip with nothing hinting at it. Parented to the
                    // viewport (Flickable children live in contentItem).
                    Rectangle {
                        parent: list
                        anchors.right: parent.right
                        anchors.rightMargin: Appearance.s(2)
                        width: Appearance.s(3)
                        radius: width / 2
                        color: Qt.alpha(Theme.surfaceFg, 0.28)
                        visible: list.contentHeight > list.height
                        height: list.height * (list.height / Math.max(list.contentHeight, 1))
                        // Origin-relative and clamped: model churn shifts
                        // originY, and raw contentY drew the thumb off-track.
                        y: Math.max(0, Math.min(list.height - height, (list.contentY - list.originY) * (list.height / Math.max(list.contentHeight, 1))))
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
                    // Wraparound: Down on the last row was a dead key.
                    Keys.onUpPressed: list.currentIndex = list.currentIndex <= 0 ? list.count - 1 : list.currentIndex - 1
                    Keys.onDownPressed: list.currentIndex = list.currentIndex >= list.count - 1 ? 0 : list.currentIndex + 1
                    Keys.onEscapePressed: root.open = false
                    // Page jumps for the empty-query case, where the list
                    // holds every installed app behind an 8-row window.
                    // (Home/End stay with the text cursor.)
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_PageUp) {
                            list.currentIndex = Math.max(0, list.currentIndex - Settings.launcherMaxShown);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_PageDown) {
                            list.currentIndex = Math.min(list.count - 1, list.currentIndex + Settings.launcherMaxShown);
                            event.accepted = true;
                        }
                    }

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
