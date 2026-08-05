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
            list.currentIndex = 0;
            list.lastHoverPos = Qt.point(-1e9, -1e9);
            field.forceActiveFocus();
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
        if (alt && row.alt)
            row.alt();
        else
            row.run();
        // Theme rows stay: picking one is comparing, and the launcher restyles
        // itself the instant the setting lands, so the panel you are looking at
        // *is* the preview. Closing after every pick would mean reopening and
        // retyping the prefix to see the next one.
        if (row.keepOpen !== true)
            root.open = false;
    }

    function activateCurrent(alt: bool): void {
        root.activate(list.currentItem?.modelData ?? null, alt);
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
        implicitWidth: Appearance.sizes.launcherWidth + Appearance.s(40)
        // Derived from launcherMaxShown rather than a constant 700: the panel
        // is bottom-anchored inside this surface, so a taller list than the
        // surface allows gets its *top* clipped away — raising that documented
        // setting past 10 silently cut the first rows off. Still constant for
        // any given setting, so the surface itself never resizes mid-use.
        implicitHeight: Appearance.s(100) + Settings.launcherMaxShown * (Appearance.sizes.launcherItemHeight + Appearance.s(4))

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
                        values: Search.results(field.text)
                        // Deliberately NOT resetting the selection here. The
                        // results depend on live state — a window retitling, a
                        // recording's elapsed time, a profile change — so this
                        // fires while you are simply arrowing down a list, and
                        // resetting on it moved the selection out from under
                        // Enter. What warrants a reset is a new *query*, which
                        // is where it now happens.
                        onValuesChanged: {
                            if (list.currentIndex >= list.count)
                                list.currentIndex = Math.max(0, list.count - 1);
                        }
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

                    delegate: ResultItem {
                        // The prefix is not part of what any row is named, so
                        // highlighting it would mark nothing.
                        query: Search.bodyOf(field.text)
                        arming: root.armed === modelData
                        onActivated: root.activate(modelData, false)
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

                    // A new query is a new list; a new list starts at the top,
                    // and nothing stays armed across it.
                    onTextChanged: {
                        list.currentIndex = 0;
                        root.armed = null;
                    }

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
                    width: Appearance.s(30)
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
