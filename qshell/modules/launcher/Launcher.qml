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
//
// Apps are only the default source. A prefix character at the front of the
// query swaps in another one — windows, a command palette, emoji, a shell
// command line — and the ? button spells all of them out; services/Search.qml
// owns what each mode finds and what Enter does with it.
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

    readonly property string mode: Search.modeOf(field.text)
    readonly property var modeInfo: Search.modeInfo(root.mode)

    // The destructive command rows (reboot, power off, log out) ask for a
    // second Enter. Held by row identity, not index: the list re-ranks under
    // the selection as you type, and arming index 3 would arm whatever landed
    // there next.
    property var armed: null

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
            list.lastHoverPos = Qt.point(-1e9, -1e9);
            field.forceActiveFocus();
        } else {
            // Reset on the way OUT, not the way in. This panel lives in
            // shell.qml and is never destroyed, so the selection outlives a
            // close — and putting it back now means the next open has nothing
            // for the highlight to animate away from. No scroll reset needed:
            // highlightFollowsCurrentItem brings the view along.
            list.currentIndex = 0;
        }
        root.armed = null;
    }

    // Entering a mode may need something loaded first — the emoji table is
    // 1400 entries nobody pays for until they ask for it.
    onModeChanged: {
        root.armed = null;
        if (root.mode === ":")
            Emoji.ensure();
    }

    function activate(row: var, alt: bool): void {
        if (!row)
            return;
        // Help rows re-enter the launcher in the mode they describe rather
        // than doing anything — the point is to leave you somewhere useful.
        if (row.switchTo !== undefined) {
            field.text = row.switchTo;
            return;
        }
        if (!row.run)
            return;
        if (row.confirm === true && root.armed !== row) {
            root.armed = row;
            return;
        }
        // A row that reports failure keeps the panel up. Closing on a launch
        // that did nothing is what made this read as "Enter was ignored" — the
        // launcher vanished and no app appeared, so the only recourse was to
        // open it and try again, which looked like needing two Enters.
        const ok = (alt && row.alt) ? row.alt() : row.run();
        if (ok === false)
            return;
        // Theme rows stay: picking one is comparing, and the launcher restyles
        // itself the instant the setting lands, so the panel you are looking at
        // *is* the preview. Closing after every pick would mean reopening and
        // retyping the prefix to see the next one.
        if (row.keepOpen !== true)
            root.open = false;
    }

    // Read the row out of the model by index, NOT via list.currentItem.
    // A ListView only instantiates delegates for rows near the viewport, so
    // currentItem is null whenever the selection is on a row that has been
    // scrolled out of the realized range — and `activate` quietly returns on
    // null, so Enter did nothing at all and said nothing about why. The model
    // always has the row, visible or not.
    function currentRow(): var {
        const rows = list.model?.values ?? [];
        const i = list.currentIndex;
        return (i >= 0 && i < rows.length) ? rows[i] : null;
    }

    function activateCurrent(alt: bool): void {
        root.activate(root.currentRow(), alt);
    }

    // Open/close the selected app's jump list. Returns false when the row has
    // no group, so the key can fall through to the text cursor.
    function toggleGroup(wantOpen: var): bool {
        return root.toggleGroupFor(root.currentRow(), wantOpen);
    }

    function toggleGroupFor(row: var, wantOpen: var): bool {
        if (!row || (row.actionCount ?? 0) === 0)
            return false;
        const open = row.expanded === true;
        if (wantOpen !== undefined && wantOpen === open)
            return false;
        const id = row.appId;
        Search.toggleExpanded(id);
        // Put the selection back on the app. Flipping the triangle changes what
        // the row *shows*, so it gets a new cache key and a new identity —
        // ScriptModel sees a removal plus an insertion and ListView slides the
        // selection off onto whatever landed at that index. Without this,
        // expanding moved the cursor three rows down and the second press could
        // not collapse what was no longer selected.
        Qt.callLater(() => {
            const rows = list.model?.values ?? [];
            const i = rows.findIndex(r => r.appId === id);
            if (i >= 0)
                list.currentIndex = i;
        });
        return true;
    }

    // Surfaced for `qs -c qshell ipc call debug launcher`. currentIndex is the
    // difference between Enter launching something and Enter doing nothing at
    // all, and it is otherwise unobservable from outside the process.
    readonly property string debugState: {
        const rows = root.open ? Search.results(field.text) : [];
        return `open=${root.open} query="${field.text}" index=${list.currentIndex} count=${list.count} rows=${rows.length} armed=${root.armed !== null} row="${root.currentRow()?.name ?? "(null)"}"`;
    }

    // Opened from elsewhere in the shell (the Control Center's theme row).
    // Unconditional rather than the IPC's toggle-on-repeat: the caller is a
    // button that says "open the picker", not a keybind pressed twice.
    Connections {
        target: Search

        function onRequestMode(prefix: string): void {
            root.open = true;
            field.text = prefix;
        }
    }

    // Swipe up from the bottom edge — the "home" gesture. A toggle, not an
    // open: the same flick has to put it away again, because on a tablet it is
    // also the only way out that doesn't involve finding Escape.
    Connections {
        target: Gestures

        function onLauncherRequested(): void {
            root.open = !root.open;
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

        // `qs ipc call launcher mode /` — opens straight into a prefix mode,
        // which is what the window-switcher keybind binds to. Pressing it
        // again closes, the way every other panel keybind behaves.
        function mode(prefix: string): string {
            if (!Search.prefixes.includes(prefix))
                return `unknown mode "${prefix}" — ${Search.prefixes.join(" ")}`;
            if (root.open && root.mode === prefix) {
                root.open = false;
                return "closed";
            }
            root.open = true;
            field.text = prefix;
            return "ok";
        }
    }

    PanelWindow {
        id: win

        screen: Quickshell.screens.find(s => s.name === (root.pinned || Hyprland.focusedMonitor?.name)) ?? Quickshell.screens[0] ?? null
        color: "transparent"
        // The strip the on-screen keyboard reserves on this screen, if any.
        // Shared by the bottom margin below and the height cap: the margin
        // lifts the surface clear of the keyboard, and without the cap that
        // lift pushed the surface's top past the screen edge — measured at
        // y=-14 with the keyboard up, the first result row clipped away.
        readonly property int oskLift: Osk.active && Osk.reservedScreen === (win.screen?.name ?? "") ? Osk.reservedPx : 0

        // Clamped to the screen the way every height already is: portrait +
        // touchScale ≥ ~1.3 made the panel wider than a 960-logical output,
        // and a bottom-anchored layer surface wider than its output gets
        // centred with BOTH edges cut. OsdPanel.maxWidth is the precedent.
        readonly property int panelW: Math.min(Appearance.sizes.launcherWidth, (win.screen?.width ?? 1920) - Appearance.s(24))

        implicitWidth: win.panelW + Appearance.s(40)
        // Derived from launcherMaxShown rather than a constant 700: the panel
        // is bottom-anchored inside this surface, so a taller list than the
        // surface allows gets its *top* clipped away — raising that documented
        // setting past 10 silently cut the first rows off. Still constant for
        // any given setting, so the surface itself never resizes mid-use —
        // except when the keyboard appears, which is a resize you can see
        // coming.
        implicitHeight: Math.min(Appearance.s(100) + Settings.launcherMaxShown * (Appearance.sizes.launcherItemHeight + Appearance.s(4)), (win.screen?.height ?? 1080) - Appearance.sizes.barHeight - win.oskLift - Appearance.s(16))

        anchors {
            bottom: true
        }

        // Above the on-screen keyboard, which is the whole point of having one:
        // the launcher is the panel you most need to type into on a tablet, and
        // it springs up from the same bottom edge. See ClipboardHistory.qml for
        // why the compositor doesn't do this for us.
        margins {
            bottom: win.oskLift
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
            // The OSK is in the whitelist because a grab treats any tap
            // outside it as "dismiss" — without this, the first key typed on
            // the on-screen keyboard closed the launcher it was typing into.
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

            width: win.panelW
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
                    // "No matches" is now only reachable in the modes that
                    // have nothing to fall back to — a plain query with no
                    // app match grows a Run row instead, and an empty command
                    // line hasn't failed to match anything yet.
                    text: root.mode === ":" && !Emoji.loaded ? "Loading emoji…" : root.mode === "!" && Search.bodyOf(field.text) === "" ? "" : "No matches"
                    color: Theme.surfaceFgDim
                }

                ListView {
                    id: list

                    // Where hover last reported the cursor in window coords —
                    // ResultItem's hover-select filter (see its comment).
                    property point lastHoverPos: Qt.point(-1e9, -1e9)

                    model: ScriptModel {
                        // The query this list was last built for. The reset to
                        // row 0 has to hang off *this*, not off the field's
                        // onTextChanged: the handler and this binding both fire
                        // from the same textChanged notification, in an order
                        // QML does not promise, and ListView independently
                        // clamps currentIndex to count-1 when a model shrinks
                        // under it. Reset last, keyed on the query actually
                        // rendered, and typing can no longer leave the
                        // selection sitting on the bottom row.
                        property string builtFor: ""

                        values: Search.results(field.text)

                        // Still NOT an unconditional reset: results also change
                        // on live state — a window retitling, a recording's
                        // elapsed time, a profile change — and resetting on
                        // those moves the selection out from under Enter while
                        // you are simply arrowing down the list.
                        onValuesChanged: {
                            if (builtFor !== field.text) {
                                builtFor = field.text;
                                list.currentIndex = 0;
                            } else if (list.currentIndex >= list.count) {
                                list.currentIndex = Math.max(0, list.count - 1);
                            } else if (list.currentIndex < 0 && list.count > 0) {
                                // The other end, and the one that bites: a
                                // ListView drops currentIndex to -1 the moment
                                // its model is momentarily empty, and the clamp
                                // above only ever looks at the upper bound — so
                                // -1 was permanent. currentRow() reads
                                // rows[-1], hands activate() undefined, and
                                // Enter does nothing at all.
                                list.currentIndex = 0;
                            }
                        }
                    }

                    width: parent.width
                    height: Math.min(count, Settings.launcherMaxShown) * (Appearance.sizes.launcherItemHeight + spacing) - (count > 0 ? spacing : 0)
                    spacing: Appearance.s(4)
                    clip: true

                    // ListView moves and animates the highlight itself. This
                    // used to be highlightFollowsCurrentItem: false plus a
                    // Rectangle binding its own y to currentItem.y behind a
                    // Behavior — a reimplementation of exactly this, which cost
                    // two bugs: the highlight slid in from the previous row on
                    // every reopen (patched with a close-reset and a
                    // positionViewAtBeginning that are now both gone), and
                    // currentItem is null for any row outside the realized
                    // range, so the highlight collapsed to y=0 height=0 when
                    // the selection scrolled off.
                    //
                    // No preferredHighlightBegin/End or ApplyRange either: the
                    // range was 0..height, i.e. the entire viewport, so it
                    // positioned nothing — while switching on the behaviour
                    // where ListView re-derives currentIndex from contentY.
                    // That is what left currentIndex at -1 and made Enter do
                    // nothing. Keeping the current row visible is what
                    // highlightFollowsCurrentItem already does.
                    highlightMoveDuration: Appearance.anim.durations.expressiveDefaultSpatial
                    highlightResizeDuration: Appearance.anim.durations.expressiveFastEffects
                    highlight: Rectangle {
                        radius: Appearance.s(16)
                        color: Theme.surfaceHoverBg
                    }

                    delegate: ResultItem {
                        // The prefix is not part of what any row is named, so
                        // highlighting it would mark nothing.
                        query: Search.bodyOf(field.text)
                        arming: root.armed === modelData
                        onActivated: root.activate(modelData, false)
                        // Clicking + selects the row it is on as well as
                        // toggling, so the keyboard and the mouse agree about
                        // what is current — the same contract hover already has.
                        onToggleRequested: {
                            list.currentIndex = index;
                            root.toggleGroupFor(modelData, undefined);
                        }
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

                // Which source you are searching. The glyph alone carries it
                // for apps; the named modes say so, because a `/` typed by
                // accident otherwise turns the app list into an unexplained
                // list of windows.
                Row {
                    id: modeChip

                    anchors.left: parent.left
                    anchors.leftMargin: Appearance.s(16)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.s(6)

                    FIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: root.mode === "" ? "search" : root.modeInfo.glyph
                        color: root.mode === "" ? Theme.surfaceFgDim : Theme.accent
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.mode !== ""
                        text: root.modeInfo.name
                        color: Theme.accent
                        font.weight: Font.DemiBold
                    }
                }

                TextInput {
                    id: field

                    anchors.left: modeChip.right
                    anchors.leftMargin: Appearance.s(10)
                    anchors.right: helpBtn.left
                    anchors.rightMargin: Appearance.s(6)
                    anchors.verticalCenter: parent.verticalCenter

                    color: Theme.surfaceFg
                    font.family: Appearance.font.family
                    font.pixelSize: Appearance.font.size.normal
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentFg
                    clip: true

                    // No currentIndex reset here. It lives on the model, keyed
                    // on the query actually rendered — see the ScriptModel
                    // above, whose comment is about this exact line: both fire
                    // off one textChanged in an order QML does not promise.
                    onTextChanged: root.armed = null

                    onAccepted: root.activateCurrent(false)
                    // Wraparound: Down on the last row was a dead key.
                    Keys.onUpPressed: list.currentIndex = list.currentIndex <= 0 ? list.count - 1 : list.currentIndex - 1
                    Keys.onDownPressed: list.currentIndex = list.currentIndex >= list.count - 1 ? 0 : list.currentIndex + 1
                    // Backing out of a mode costs one Esc, closing the panel
                    // the next — being dropped all the way out of the launcher
                    // for mistyping a prefix is a bad trade.
                    Keys.onEscapePressed: {
                        if (root.mode !== "")
                            field.text = "";
                        else
                            root.open = false;
                    }
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
                        } else if (event.key === Qt.Key_Right && field.cursorPosition === field.text.length) {
                            // Only at the end of the text, so Right keeps
                            // working as a text cursor everywhere it would
                            // actually move. Expands the selected app's jump
                            // list; a second press collapses it.
                            event.accepted = root.toggleGroup(undefined);
                        } else if (event.key === Qt.Key_Left && field.cursorPosition === 0) {
                            // The mirror, and only ever a collapse — Left at
                            // the start of an empty query should not open
                            // something.
                            event.accepted = root.toggleGroup(false);
                        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ShiftModifier)) {
                            // The row's alternate verb, where it has one —
                            // onAccepted can't see modifiers.
                            root.activateCurrent(true);
                            event.accepted = true;
                        }
                    }

                    StyledText {
                        visible: !field.text
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        text: Search.placeholder(field.text)
                        color: Theme.surfaceFgDim
                        elide: Text.ElideRight
                    }
                }

                // The prefixes are the whole point of the rewrite and nothing
                // on screen would otherwise name them. One tap lists every
                // mode and every key, and each row walks you into that mode.
                Item {
                    id: helpBtn

                    anchors.right: parent.right
                    anchors.rightMargin: Appearance.s(8)
                    anchors.verticalCenter: parent.verticalCenter
                    // Touch floor: at s(30) this was a 35-43px target on the
                    // panel a finger uses most. 0 outside touch mode.
                    width: Math.max(Appearance.s(30), Appearance.touchTarget)
                    height: width

                    StateLayer {
                        radius: width / 2
                        color: Theme.surfaceFg
                        onClicked: {
                            field.text = root.mode === "?" ? "" : "?";
                            field.forceActiveFocus();
                        }
                    }

                    FIcon {
                        anchors.centerIn: parent
                        icon: "question_circle"
                        color: root.mode === "?" ? Theme.accent : Theme.surfaceFgDim
                    }
                }
            }
        }
    }
}
