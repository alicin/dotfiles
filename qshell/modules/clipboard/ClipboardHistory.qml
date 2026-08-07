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

    // True from the moment the panel opens until the selection first moves off
    // card 0, and the actual fix for "it opens on the last card".
    //
    // Two things conspire. Clipboard.refresh() is a subprocess, so the real
    // list lands well after onOpenChanged — a reset written there is applied to
    // a model that is about to be replaced. And highlightRangeMode is
    // ApplyRange, which means the ListView does not merely *follow*
    // currentIndex, it re-derives it from whatever item sits in the preferred
    // range as contentX changes; during the open relayout that resolved to the
    // far end, landing on index 749 of 750. Right then wrapped modulo count
    // straight back to the first card, which is the jump you see.
    //
    // So the reset cannot be a one-shot. While this is set, every model rebuild
    // re-asserts card 0.
    property bool openingReset: false

    // Surfaced for `qs -c qshell ipc call debug clip`. The picker's selection
    // and scroll offset are otherwise unobservable from outside the process,
    // which made "does it really open on the first card?" a question only
    // screenshots could answer — and screenshots of a list whose contents keep
    // changing answer it badly.
    readonly property string debugState: `open=${root.open} filter="${root.filter}" query="${field.text}" index=${list.currentIndex} count=${list.count} contentX=${Math.round(list.contentX)}`

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
            root.openingReset = true;
            list.currentIndex = 0;
            list.positionViewAtBeginning();
            // Again after this layout pass: the panel is being shown, and the
            // view's own relayout runs after this handler.
            Qt.callLater(() => {
                if (root.open) {
                    list.currentIndex = 0;
                    list.positionViewAtBeginning();
                }
            });
            list.lastHoverPos = Qt.point(-1e9, -1e9);
            clearBtn.armed = false;
            field.forceActiveFocus();
        } else {
            root.openingReset = false;
            // Reset on the way OUT as well as in. This panel is instantiated
            // in shell.qml and is never destroyed — unlike the bar popouts,
            // whose Loader rebuilds them every time — so currentIndex and
            // contentX survive a close. Putting the strip back now means the
            // next open finds it already on card 0 at x=0, and there is
            // nothing for highlightMoveDuration to animate; resetting only on
            // open left the highlight sliding in from wherever it had been.
            list.currentIndex = 0;
            list.positionViewAtBeginning();
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

    // The QR plate for the selected card. Session state, not a mode: it sits
    // over the picker and Escape takes it away again.
    property bool qrOpen: false

    function showQrCurrent(): void {
        const entry = list.currentItem?.modelData;
        if (!entry || !Clipboard.qrCapable(entry))
            return;
        Clipboard.encodeQr(entry);
        root.qrOpen = true;
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
            //
            // So is the QR plate, and it has to be: a second surface the grab
            // does not know about reads as a click outside, onCleared fires,
            // and the picker closes out from under the code it just raised.
            windows: {
                const w = [win];
                if (Osk.panelWindow)
                    w.push(Osk.panelWindow);
                if (qrLoader.item)
                    w.push(qrLoader.item);
                return w;
            }
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

                        // No currentIndex reset here — it lives on the model,
                        // keyed on the query actually rendered. See the
                        // ScriptModel below.

                        onAccepted: root.copyCurrent()
                        Keys.onLeftPressed: root.move(-1)
                        Keys.onRightPressed: root.move(1)
                        // Escape peels one layer at a time: the QR plate first,
                        // the picker only once it is gone.
                        Keys.onEscapePressed: {
                            if (root.qrOpen)
                                root.qrOpen = false;
                            else
                                root.open = false;
                        }
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
                            } else if (event.key === Qt.Key_Q && (event.modifiers & Qt.ControlModifier)) {
                                // Q for QR, following Ctrl+P / Ctrl+D. Worth
                                // knowing: with the macOS modmaps on, physical
                                // Cmd+Q arrives here as Ctrl+Q, so a reflexive
                                // quit raises a code instead. Harmless — the
                                // picker is not an app you quit, and Escape
                                // takes the plate away.
                                root.showQrCurrent();
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

                    // The moment the selection genuinely leaves card 0 — by
                    // key, hover or click — the panel is being driven and the
                    // opening reset must stop firing, or the next rebuild
                    // (pinning a card, say) would yank the strip back. One
                    // watcher rather than clearing the flag in each of the four
                    // call sites that can move the selection.
                    onCurrentIndexChanged: {
                        if (list.currentIndex > 0)
                            root.openingReset = false;
                    }

                    model: ScriptModel {
                        // The reset hangs off the MODEL, keyed on what was
                        // actually rendered — the same fix the launcher's list
                        // carries, for the same reason. Resetting from
                        // field.onTextChanged and root.onFilterChanged instead
                        // raced this binding: both fire off the same
                        // notification in an order QML does not promise, and
                        // ListView independently clamps currentIndex to
                        // count-1 when the model shrinks under it. That is how
                        // opening the panel could land on the LAST card — and
                        // then Right would wrap modulo count straight back to
                        // the first.
                        property string builtFor: ""

                        values: Clipboard.search(field.text, root.filter)

                        onValuesChanged: {
                            // Filter and query together: either one changing is
                            // a different list, and both must land on card 0.
                            const key = `${root.filter}\t${field.text}`;
                            // Still opening: whatever the model just did, the
                            // answer is card 0. This is the branch that fixes
                            // the reopen — refresh() lands here, long after
                            // onOpenChanged has had its say.
                            if (root.openingReset) {
                                builtFor = key;
                                list.currentIndex = 0;
                                list.positionViewAtBeginning();
                                return;
                            }
                            if (builtFor !== key) {
                                builtFor = key;
                                list.currentIndex = 0;
                                list.positionViewAtBeginning();
                            } else if (list.currentIndex >= list.count) {
                                // Still NOT an unconditional reset: pinning a
                                // card rebuilds the list (the pin sorts to the
                                // front), and throwing the strip back to the
                                // beginning moved the card you just pinned out
                                // from under you.
                                list.currentIndex = Math.max(0, list.count - 1);
                            }
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

    // ── QR plate ──────────────────────────────────────────────────────────
    //
    // Its own surface, not a layer inside the picker: the picker's window is a
    // bottom strip capped at 460px, and a plate does not fit in it without
    // resizing the Wayland surface every time it opens — which rules.lua would
    // then animate underneath the real thing (the trap the OSD fell into).
    //
    // A LazyLoader so nothing is mapped until a code is actually asked for, and
    // so the picker's focus grab can whitelist `qrLoader.item` by identity.
    LazyLoader {
        id: qrLoader

        active: root.qrOpen

        PanelWindow {
            id: qrWin

            screen: Quickshell.screens.find(s => s.name === (root.pinned || Hyprland.focusedMonitor?.name)) ?? Quickshell.screens[0] ?? null
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            WlrLayershell.namespace: "qshell:clipqr"
            WlrLayershell.layer: WlrLayer.Overlay
            // The picker keeps the keyboard — Escape and the arrows still belong
            // to it, and taking focus here would break the layer it sits on.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Theme.shadow, 0.5)

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.qrOpen = false
                }

                Elevation {
                    anchors.fill: plate
                    radius: plate.radius
                    level: 4
                }

                Rectangle {
                    id: plate

                    anchors.centerIn: parent
                    width: Appearance.s(300)
                    height: Appearance.s(300) + label.height + Appearance.s(28)
                    radius: Appearance.s(18)
                    // Deliberately NOT a Theme colour, and the one place in the
                    // shell that ignores the palette on purpose: a QR code is
                    // read by a camera, and the spec's contrast assumption is
                    // dark modules on a light ground. Inverting it for a dark
                    // theme produces a code many scanners refuse. The chrome
                    // around it is themed; the code and its quiet zone are not.
                    color: "#ffffff"

                    Image {
                        id: qrImage

                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: Appearance.s(14)
                        width: Appearance.s(272)
                        height: width
                        visible: Clipboard.qrData !== ""
                        // One pixel per module out of qrencode, scaled by an
                        // integer with no smoothing — a filtered QR is a blurred
                        // QR, and blurred is unscannable.
                        smooth: false
                        fillMode: Image.PreserveAspectFit
                        source: Clipboard.qrData === "" ? "" : `data:image/png;base64,${Clipboard.qrData}`
                    }

                    StyledText {
                        anchors.centerIn: qrImage
                        visible: Clipboard.qrPending || Clipboard.qrFailed
                        width: parent.width - Appearance.s(40)
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: Clipboard.qrPending ? "Encoding…" : "Too long to encode as a QR code"
                        color: "#666666"
                        font.pixelSize: Appearance.font.size.small
                    }

                    StyledText {
                        id: label

                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: qrImage.bottom
                        anchors.topMargin: Appearance.s(8)
                        width: parent.width - Appearance.s(28)
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideMiddle
                        text: Clipboard.entryText(list.currentItem?.modelData ?? null) || ""
                        // Against the white plate, not the theme surface.
                        color: "#444444"
                        font.pixelSize: Appearance.font.size.small
                    }
                }
            }
        }
    }
}
