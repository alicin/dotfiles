import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

// Clipboard history in the shape of macOS Paste: a wide strip across the
// bottom of the screen holding one card per entry, side by side, each showing
// who copied it, the content itself at a size worth reading, and what it is.
//
// The list it replaces could show one line of anything, which is the wrong
// line as soon as you are looking for the second URL you copied off a page or
// the right one of four screenshots. Cards trade the number of entries on
// screen for actually recognising them — and the search field is right there
// for when there are more than fit.
//
// Backed by the same cliphist store as before (`wl-paste --watch` →
// scripts/clip-store.sh), so history carries over. Pins live outside cliphist
// entirely; see services/Clipboard.qml.
Scope {
    id: root

    property bool open: false

    // Pinned by NAME, not by object — see the launcher's identical pin for
    // what a severed screen binding costs when a monitor comes and goes.
    property string pinned: ""

    // The window the picker was opened over, for paste-on-select. Read at open
    // and held, because the picker takes the focus grab the moment it comes up
    // and from then on the active toplevel is the picker's own layer, not the
    // window the paste is meant for.
    property string pasteAddr: ""
    property string pasteClass: ""

    // Which of the filter chips is active — "all" plus the kinds
    // Clipboard.kindOf() can name.
    property string filter: "all"

    readonly property var filters: [
        {
            key: "all",
            label: "All",
            glyph: "square_stack"
        },
        {
            key: "pinned",
            label: "Pinned",
            glyph: "pin_fill"
        },
        {
            key: "text",
            label: "Text",
            glyph: "textformat"
        },
        {
            key: "link",
            label: "Links",
            glyph: "link"
        },
        {
            key: "image",
            label: "Images",
            glyph: "photo"
        },
        {
            key: "file",
            label: "Files",
            glyph: "doc"
        },
        {
            key: "color",
            label: "Colors",
            glyph: "circle_grid_hex"
        }
    ]

    onOpenChanged: {
        // The OSD shares this panel's bottom-center spot.
        Osd.clipboardOpen = open;
        if (open) {
            root.pinned = Hyprland.focusedMonitor?.name ?? "";
            const toplevel = Hyprland.activeToplevel;
            root.pasteAddr = Clipboard.windowAddress(toplevel?.lastIpcObject?.address ?? toplevel?.address ?? "");
            root.pasteClass = `${toplevel?.lastIpcObject?.class || toplevel?.wayland?.appId || ""}`;
            if (Osd.kind !== "countdown")
                Osd.hide();
            Clipboard.refresh();
            field.text = "";
            root.filter = "all";
            list.currentIndex = 0;
            list.lastHoverPos = Qt.point(-1e9, -1e9);
            clearBtn.armed = false;
            field.forceActiveFocus();
        }
    }

    function copyCurrent(): void {
        list.currentItem?.take();
    }

    function removeCurrent(): void {
        list.currentItem?.drop();
    }

    function togglePinCurrent(): void {
        const item = list.currentItem;
        if (item)
            Clipboard.togglePin(item.modelData);
    }

    // Left/Right walk the strip. They cost the text cursor its arrow keys,
    // which is the right trade: this is a picker with a search field, not a
    // text editor — and the whole point of the layout is moving along a row.
    function move(d: int): void {
        if (list.count === 0)
            return;
        list.currentIndex = (list.currentIndex + d + list.count) % list.count;
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
        implicitHeight: Appearance.s(460)

        anchors {
            bottom: true
            left: true
            right: true
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

        Rectangle {
            id: panel

            property real offsetScale: root.open ? 0 : 1

            readonly property int pad: Appearance.s(14)

            visible: offsetScale < 1
            opacity: 1 - offsetScale
            y: win.height - (height + Appearance.s(14)) * (1 - offsetScale)
            anchors.horizontalCenter: parent.horizontalCenter

            // As wide as the screen allows, because the point of the strip is
            // how many cards are on it — capped so it doesn't become a band on
            // an ultrawide.
            width: Math.min(win.width - Appearance.s(60), Appearance.s(1500))
            height: pad + header.height + Appearance.s(10) + strip.height + Appearance.s(8) + hints.height + pad
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

            // ── Header: search, kind filters, clear ──
            Item {
                id: header

                x: panel.pad
                y: panel.pad
                width: panel.width - panel.pad * 2
                height: Appearance.s(40)

                Rectangle {
                    id: searchBg

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Appearance.s(280)
                    height: Appearance.s(36)
                    radius: height / 2
                    color: Theme.surfaceHoverBg

                    FIcon {
                        id: searchIcon

                        anchors.left: parent.left
                        anchors.leftMargin: Appearance.s(14)
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "search"
                        color: Theme.surfaceFgDim
                    }

                    TextInput {
                        id: field

                        anchors.left: searchIcon.right
                        anchors.leftMargin: Appearance.s(8)
                        anchors.right: parent.right
                        anchors.rightMargin: Appearance.s(14)
                        anchors.verticalCenter: parent.verticalCenter

                        color: Theme.surfaceFg
                        font.family: Appearance.font.family
                        font.pixelSize: Appearance.font.size.normal
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.accentFg
                        clip: true

                        onAccepted: root.copyCurrent()
                        Keys.onLeftPressed: root.move(-1)
                        Keys.onRightPressed: root.move(1)
                        Keys.onEscapePressed: root.open = false
                        // Shift+Delete drops an entry — plain Delete has to
                        // stay available for editing the query.
                        Keys.onDeletePressed: event => {
                            if (event.modifiers & Qt.ShiftModifier)
                                root.removeCurrent();
                            else
                                event.accepted = false;
                        }
                        Keys.onPressed: event => {
                            // A held key repeats ~25 times a second and a card
                            // does not read as pinned until its payload has
                            // landed — every one of those repeats would be
                            // another pin of the same thing.
                            if (event.isAutoRepeat)
                                return;
                            // Ctrl+P pins, Ctrl+D drops — the two verbs a card
                            // shows buttons for, for the hand already on the
                            // keyboard.
                            if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
                                root.togglePinCurrent();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_D && (event.modifiers & Qt.ControlModifier)) {
                                root.removeCurrent();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Tab) {
                                // Walks the filter chips, which are otherwise
                                // mouse-only.
                                const i = root.filters.findIndex(f => f.key === root.filter);
                                root.filter = root.filters[(i + 1) % root.filters.length].key;
                                event.accepted = true;
                            }
                        }

                        StyledText {
                            visible: !field.text
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Search clipboard…"
                            color: Theme.surfaceFgDim
                        }
                    }
                }

                Row {
                    id: chips

                    anchors.left: searchBg.right
                    anchors.leftMargin: Appearance.s(12)
                    anchors.right: clearBtn.left
                    anchors.rightMargin: Appearance.s(12)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.s(6)
                    clip: true

                    Repeater {
                        model: root.filters

                        Rectangle {
                            id: chip

                            required property var modelData

                            readonly property bool active: root.filter === modelData.key

                            implicitWidth: chipRow.implicitWidth + Appearance.s(20)
                            implicitHeight: Appearance.s(30)
                            radius: height / 2
                            color: active ? Theme.accent : Theme.surfaceHoverBg

                            Behavior on color {
                                CAnim {}
                            }

                            StateLayer {
                                radius: parent.radius
                                color: chip.active ? Theme.accentFg : Theme.surfaceFg
                                onClicked: root.filter = chip.modelData.key
                            }

                            Row {
                                id: chipRow

                                anchors.centerIn: parent
                                spacing: Appearance.s(5)

                                FIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    icon: chip.modelData.glyph
                                    font.pixelSize: Appearance.s(14)
                                    color: chip.active ? Theme.accentFg : Theme.surfaceFgDim
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: chip.modelData.label
                                    color: chip.active ? Theme.accentFg : Theme.surfaceFg
                                    font.pixelSize: Appearance.font.size.small
                                }
                            }
                        }
                    }
                }

                // Wipe the history. Two taps, and it says so in between: this
                // is the one control here that destroys something.
                Rectangle {
                    id: clearBtn

                    property bool armed: false

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: clearRow.implicitWidth + Appearance.s(18)
                    implicitHeight: Appearance.s(30)
                    radius: height / 2
                    color: armed ? Theme.urgent : Theme.surfaceHoverBg

                    Behavior on color {
                        CAnim {}
                    }

                    onArmedChanged: {
                        if (armed)
                            disarm.restart();
                    }

                    Timer {
                        id: disarm

                        interval: 3000
                        onTriggered: clearBtn.armed = false
                    }

                    StateLayer {
                        radius: parent.radius
                        color: clearBtn.armed ? Theme.accentFg : Theme.urgent
                        onClicked: {
                            if (!clearBtn.armed) {
                                clearBtn.armed = true;
                                return;
                            }
                            clearBtn.armed = false;
                            Clipboard.wipe();
                        }
                    }

                    Row {
                        id: clearRow

                        anchors.centerIn: parent
                        spacing: Appearance.s(5)

                        FIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "trash"
                            font.pixelSize: Appearance.s(14)
                            color: clearBtn.armed ? Theme.accentFg : Theme.surfaceFgDim
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            // Pins are not history and do not go with it —
                            // which is the whole reason they exist.
                            text: clearBtn.armed ? "Erase history?" : "Clear"
                            color: clearBtn.armed ? Theme.accentFg : Theme.surfaceFg
                            font.pixelSize: Appearance.font.size.small
                            font.weight: clearBtn.armed ? Font.Bold : Font.Medium
                        }
                    }
                }
            }

            // ── The strip ──
            Item {
                id: strip

                x: panel.pad
                anchors.top: header.bottom
                anchors.topMargin: Appearance.s(10)
                width: panel.width - panel.pad * 2
                height: Appearance.sizes.clipCardHeight + Appearance.s(12)

                StyledText {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    // Blank until the first listing lands — flashing
                    // "Clipboard is empty" for the round trip read as data loss
                    // for a beat.
                    text: !Clipboard.loaded ? "" : field.text ? "Nothing matches" : root.filter !== "all" ? "Nothing of that kind yet" : "Clipboard is empty"
                    color: Theme.surfaceFgDim
                }

                ListView {
                    id: list

                    // Where hover last reported the cursor in window coords —
                    // ClipCard's hover-select filter (see its comment).
                    property point lastHoverPos: Qt.point(-1e9, -1e9)

                    anchors.fill: parent
                    orientation: ListView.Horizontal
                    spacing: Appearance.s(12)
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    // Keep the selected card on screen with a card's worth of
                    // context either side, so arrowing along the strip scrolls
                    // before you reach the edge rather than after.
                    preferredHighlightBegin: Appearance.sizes.clipCardWidth
                    preferredHighlightEnd: width - Appearance.sizes.clipCardWidth
                    highlightRangeMode: ListView.ApplyRange
                    highlightMoveDuration: Appearance.anim.durations.expressiveFastSpatial

                    model: ScriptModel {
                        values: Clipboard.search(field.text, root.filter)
                        onValuesChanged: list.currentIndex = 0
                    }

                    delegate: ClipCard {
                        pasteAddr: root.pasteAddr
                        pasteClass: root.pasteClass
                        onActivated: root.open = false
                        // The model reset yanked the selection to the front on
                        // every delete — stay where the user was.
                        onRemoved: at => list.currentIndex = Math.min(at, list.count - 1)
                    }

                    WheelScroll {
                        view: list
                    }
                }
            }

            // ── Key legend ──
            //
            // Paste's own footer, and for the same reason the launcher grew a
            // ? button: none of this is discoverable by looking at cards.
            Row {
                id: hints

                anchors.bottom: parent.bottom
                anchors.bottomMargin: panel.pad
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Appearance.s(14)

                Repeater {
                    model: [
                        {
                            k: "← →",
                            v: "select"
                        },
                        {
                            k: "⏎",
                            v: Settings.clipboardPaste ? "paste" : "copy"
                        },
                        {
                            k: "⇥",
                            v: "filter"
                        },
                        {
                            k: "⌃P",
                            v: "pin"
                        },
                        {
                            k: "⌃D",
                            v: "delete"
                        },
                        {
                            k: "esc",
                            v: "close"
                        }
                    ]

                    Row {
                        required property var modelData

                        spacing: Appearance.s(4)

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.modelData.k
                            color: Theme.surfaceFg
                            font.pixelSize: Appearance.font.size.small
                            font.weight: Font.DemiBold
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.modelData.v
                            color: Theme.surfaceFgDim
                            font.pixelSize: Appearance.font.size.small
                            font.weight: Font.Normal
                        }
                    }
                }
            }
        }
    }
}
