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

    onFilterChanged: list.currentIndex = 0

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

        readonly property int oskLift: Osk.active && Osk.reservedScreen === (win.screen?.name ?? "") ? Osk.reservedPx : 0

        screen: Quickshell.screens.find(s => s.name === (root.pinned || Hyprland.focusedMonitor?.name)) ?? Quickshell.screens[0] ?? null
        color: "transparent"
        // Capped like the launcher: lifted over the keyboard, the fixed height
        // has to give, or the strip's top goes past the screen edge.
        implicitHeight: Math.min(Appearance.s(460), (win.screen?.height ?? 1080) - Appearance.sizes.barHeight - win.oskLift - Appearance.s(16))

        anchors {
            bottom: true
            left: true
            right: true
        }

        // Lifted clear of the on-screen keyboard. Everything bottom-anchored in
        // this shell opts out of exclusive zones so it can sit over the bar's,
        // and the keyboard's reservation comes through that same door — so the
        // compositor will not move this panel and it has to move itself.
        margins {
            bottom: win.oskLift
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
            // The OSK is whitelisted so typing into the filter field from the
            // on-screen keyboard doesn't dismiss the picker on the first key.
            windows: Osk.panelWindow ? [win, Osk.panelWindow] : [win]
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
            // Edge to edge along the bottom, the way Paste's own bar sits: the
            // whole point of the strip is how many cards are on it, and a
            // floating card of a window spent screen width on margins to look
            // like a dialog — which this is not. Only the top corners round,
            // because the other two are off the screen.
            x: 0
            y: win.height - height * (1 - offsetScale)
            width: win.width
            height: pad + header.height + Appearance.s(10) + strip.height + Appearance.s(8) + hints.height + pad
            radius: Appearance.sizes.launcherRadius
            bottomLeftRadius: 0
            bottomRightRadius: 0
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

                // Kinds on the left, search on the right — Paste's own toolbar
                // order, and the one that survives a full-width panel: the
                // chips are what you point at, so they belong at the edge the
                // cards start from, not stranded in the middle of a screen's
                // worth of header.
                Rectangle {
                    id: searchBg

                    anchors.right: clearBtn.left
                    anchors.rightMargin: Appearance.s(10)
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

                        onTextChanged: list.currentIndex = 0

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

                // Scrollable when it overflows, inert when everything fits
                // (the Popouts pattern). In portrait the header leaves
                // ~330-460px for seven chips needing ~520-650: the tail chips
                // (Images/Files/Colors) were clipped off with no route to
                // them by touch at all.
                Flickable {
                    id: chipsFlick

                    anchors.left: parent.left
                    anchors.right: count.left
                    anchors.rightMargin: Appearance.s(12)
                    anchors.verticalCenter: parent.verticalCenter
                    height: chips.implicitHeight
                    contentWidth: chips.implicitWidth
                    clip: true
                    interactive: contentWidth > width
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.HorizontalFlick

                    Row {
                    id: chips

                    spacing: Appearance.s(6)

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
                }

                // How much is behind the strip — the count is the only thing
                // that says whether scrolling on is worth it, since the cards
                // themselves run off the right edge either way.
                StyledText {
                    id: count

                    anchors.right: searchBg.left
                    anchors.rightMargin: Appearance.s(14)
                    anchors.verticalCenter: parent.verticalCenter
                    text: list.count === 0 ? "" : `${list.count} item${list.count === 1 ? "" : "s"}`
                    color: Theme.surfaceFgDim
                    font.pixelSize: Appearance.font.size.small
                    font.weight: Font.Normal
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
                        // Not a reset: pinning a card rebuilds the list (the
                        // pin sorts to the front) and this used to throw the
                        // strip back to the beginning, away from the card you
                        // just pinned. A new query or filter resets instead.
                        onValuesChanged: {
                            if (list.currentIndex >= list.count)
                                list.currentIndex = Math.max(0, list.count - 1);
                        }
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

                    // The same thin thumb the launcher and the notification
                    // list grew, turned on its side. Without it the strip was
                    // the one list in the shell that ran off its own edge with
                    // nothing saying how far — and it is also the one holding
                    // the most rows. Parented to the viewport: Flickable
                    // children live in contentItem and would scroll away.
                    Rectangle {
                        parent: list
                        anchors.bottom: parent.bottom
                        height: Appearance.s(3)
                        radius: height / 2
                        color: Qt.alpha(Theme.surfaceFg, 0.28)
                        visible: list.contentWidth > list.width
                        width: list.width * (list.width / Math.max(list.contentWidth, 1))
                        // Origin-relative and clamped: model churn shifts
                        // originX, and raw contentX drew the thumb off-track.
                        x: Math.max(0, Math.min(list.width - width, (list.contentX - list.originX) * (list.width / Math.max(list.contentWidth, 1))))
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
