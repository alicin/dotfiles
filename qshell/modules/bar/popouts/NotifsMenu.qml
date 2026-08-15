import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// Notification center: DND toggle, clear-all, recent notifications grouped by
// the app that sent them.
//
// Grouping is what makes the list readable once anything chatty is installed:
// twelve messages from one client used to push everything else off the bottom,
// and there was no way to tell that app to be quiet without turning off
// notifications entirely. Each group header carries the count and a mute
// toggle for exactly that.
Column {
    id: root

    // Apps whose runs are collapsed to the first few. Kept here rather than in
    // the service: it's a view state, and it should reset when the menu does.
    property var collapsed: ({})
    // Bumped on every write, because mutating a plain object doesn't notify.
    property int collapseRev: 0

    // How many of a group's notifications show before the "+n more" row.
    readonly property int collapseAt: 3

    function isCollapsed(app: string): bool {
        return root.collapseRev >= 0 && (root.collapsed[app] ?? true);
    }

    function toggleCollapsed(app: string): void {
        root.collapsed[app] = !root.isCollapsed(app);
        root.collapseRev++;
    }

    // Row objects are cached and reused, because ScriptModel diffs by
    // *identity*: rebuilding them fresh would replace every row on every
    // arrival, throwing away each card's expand state and playing the
    // remove/add transitions across the whole list. Nothing mutable lives in
    // a row — counts and mute state are read live in the delegate — so a
    // cached row never goes stale.
    property var headerCache: ({})
    property var moreCache: ({})

    // Group order, pinned for as long as the menu is open. `grouped` ranks
    // apps by their newest notification, so dismissing the top group's newest
    // items could re-rank it mid-clear: the half-cleared group teleported down
    // the list and the next app surfaced under the cursor. A group keeps its
    // slot until it disappears; new apps still enter at the top. Mutated in
    // place (like the row caches) so the rows binding doesn't observe it.
    property var appOrder: []

    // The list flattened into rows the ListView can render: a header per app,
    // then its notifications, then a "+n more" row when the run is collapsed.
    // Flat rather than nested views — a ListView inside a ListView delegate
    // has no usable content height, and this list has to size the popout.
    readonly property var rows: {
        const groups = Notifs.grouped;
        // Reverse iteration keeps grouped's newest-first order among apps
        // that arrive together (each unshifts in front of the previous).
        for (let i = groups.length - 1; i >= 0; i--)
            if (!root.appOrder.includes(groups[i].app))
                root.appOrder.unshift(groups[i].app);

        const out = [];
        for (const g of [...groups].sort((a, b) => root.appOrder.indexOf(a.app) - root.appOrder.indexOf(b.app))) {
            if (!root.headerCache[g.app])
                root.headerCache[g.app] = ({
                        kind: "header",
                        app: g.app
                    });
            out.push(root.headerCache[g.app]);

            const collapsed = root.isCollapsed(g.app) && g.items.length > root.collapseAt;
            const shown = collapsed ? g.items.slice(0, root.collapseAt) : g.items;
            for (const w of shown) {
                // Parked on the wrapper itself: it's the only per-notification
                // identity that outlives a regroup, and the wrappers are this
                // shell's own objects.
                if (!w.row)
                    w.row = ({
                            kind: "item",
                            app: g.app,
                            w
                        });
                out.push(w.row);
            }

            if (collapsed) {
                if (!root.moreCache[g.app])
                    root.moreCache[g.app] = ({
                            kind: "more",
                            app: g.app
                        });
                out.push(root.moreCache[g.app]);
            }
        }
        return out;
    }

    width: Appearance.s(400)
    spacing: Appearance.s(2)

    // Only after the menu has dwelt open does it count as "the user saw
    // these": hover-slide can flash this menu for 50ms in transit to another
    // module, and a pass-through must neither absorb toasts nor clear the
    // badge. The badge write itself is further deferred by requestSeen until
    // every menu is closed — see the note in services/Notifs.qml.
    Timer {
        id: dwell

        interval: 600
        running: true
        onTriggered: Notifs.absorbPopups()
    }

    Component.onDestruction: {
        if (!dwell.running)
            Notifs.requestSeen();
    }

    Item {
        width: parent.width
        height: Appearance.sizes.menuRowHeight

        StyledText {
            id: title

            anchors.verticalCenter: parent.verticalCenter
            text: "Notifications"
            color: Theme.surfaceFg
        }

        StyledText {
            anchors.left: title.right
            anchors.leftMargin: Appearance.s(8)
            anchors.verticalCenter: parent.verticalCenter
            visible: Notifs.count > 0
            text: `${Notifs.count}`
            color: Theme.surfaceFgDim
            font.pixelSize: Appearance.font.size.small
        }

        Rectangle {
            visible: Notifs.count > 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: clearLabel.implicitWidth + Appearance.s(20)
            implicitHeight: Appearance.s(26)
            radius: height / 2
            color: Theme.surfaceHoverBg

            StateLayer {
                radius: parent.radius
                color: Theme.surfaceFg
                onClicked: Notifs.clearAll()
            }

            StyledText {
                id: clearLabel

                anchors.centerIn: parent
                text: "Clear"
                color: Theme.surfaceFg
                font.pixelSize: Appearance.font.size.small
            }
        }
    }

    Item {
        width: parent.width
        height: Appearance.sizes.menuRowHeight

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: "Do not disturb"
            color: Theme.surfaceFg
        }

        StyledSwitch {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: Notifs.dnd
            onToggled: Notifs.toggleDnd()
        }
    }

    MenuSeparator {
        width: parent.width
    }

    StyledText {
        visible: Notifs.count === 0
        height: Appearance.sizes.menuRowHeight
        text: "No notifications"
        color: Theme.surfaceFgDim
    }

    ListView {
        id: list

        width: parent.width
        implicitHeight: Math.min(contentHeight, Appearance.s(430))
        visible: Notifs.count > 0
        clip: true
        spacing: Appearance.s(4)
        // Short lists shouldn't drag-bounce; long ones stop at their ends —
        // same treatment as the wifi network list.
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        // No phantom selection until the keyboard asks for one.
        currentIndex: -1
        highlightMoveDuration: Appearance.anim.durations.expressiveFastEffects
        highlightResizeDuration: Appearance.anim.durations.expressiveFastEffects

        highlight: Rectangle {
            radius: Appearance.s(10)
            color: Theme.surfaceHoverBg
        }

        // Dismissals slide out the way toasts slide in; survivors glide up
        // instead of teleporting.
        remove: Transition {
            Anim {
                properties: "opacity"
                to: 0
                duration: Appearance.anim.durations.expressiveFastEffects
            }

            Anim {
                properties: "x"
                to: Appearance.s(24)
                duration: Appearance.anim.durations.expressiveFastEffects
            }
        }

        displaced: Transition {
            Anim {
                properties: "y"
                curve: Appearance.anim.curves.emphasized
                duration: Appearance.anim.durations.small
            }
        }

        WheelScroll {
            view: list
        }

        model: ScriptModel {
            values: root.rows
        }

        // Three row shapes in one delegate: a Loader per row would rebuild the
        // notification cards on every regroup, and they hold the expand state.
        delegate: Item {
            id: row

            required property var modelData

            readonly property bool isItem: modelData.kind === "item"
            // Read live rather than stored in the row, so a cached row object
            // can keep its identity while its counts move.
            readonly property int groupCount: Notifs.groupCount(modelData.app)
            readonly property bool groupMuted: Notifs.isMuted(modelData.app)

            width: list.width
            implicitHeight: row.isItem ? card.implicitHeight : Appearance.s(26)

            // Keyboard nav walks items only; the ListView still needs to know
            // whether this row can take the highlight.
            function activate(): void {
                if (row.isItem)
                    card.activate();
                else if (row.modelData.kind === "more")
                    root.toggleCollapsed(row.modelData.app);
            }

            function dismiss(): void {
                if (row.isItem)
                    row.modelData.w.n?.dismiss();
            }

            // ── App header ──
            Item {
                anchors.fill: parent
                visible: row.modelData.kind === "header"

                StyledText {
                    id: appName

                    anchors.left: parent.left
                    anchors.leftMargin: Appearance.s(4)
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.app
                    color: row.groupMuted ? Theme.surfaceFgDim : Theme.accent
                    font.pixelSize: Appearance.font.size.small
                    font.weight: Font.Bold
                }

                StyledText {
                    anchors.left: appName.right
                    anchors.leftMargin: Appearance.s(6)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.groupCount > 1
                    text: `${row.groupCount}`
                    color: Theme.surfaceFgDim
                    font.pixelSize: Appearance.font.size.small
                }

                // Mute this sender. The single choke point for it is one line
                // in the server's handler, and this is the only place you'd
                // ever think to look for the switch.
                Item {
                    id: muteBtn

                    anchors.right: parent.right
                    anchors.rightMargin: Appearance.s(4)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Appearance.s(22)
                    height: width

                    StateLayer {
                        radius: width / 2
                        color: Theme.surfaceFg
                        onClicked: Notifs.toggleMute(row.modelData.app)
                    }

                    FIcon {
                        anchors.centerIn: parent
                        icon: row.groupMuted ? "bell_slash_fill" : "bell"
                        font.pixelSize: Appearance.font.size.small
                        color: row.groupMuted ? Theme.warn : Theme.surfaceFgDim
                    }
                }
            }

            // ── Notification ──
            NotificationCard {
                id: card

                width: parent.width
                visible: row.isItem
                // A destroyed wrapper would throw every binding in the card;
                // the header rows have none to give.
                wrapper: row.isItem ? row.modelData.w : null
                flat: true
            }

            // ── "+n more" ──
            Item {
                anchors.fill: parent
                visible: row.modelData.kind === "more"

                StateLayer {
                    radius: Appearance.s(8)
                    color: Theme.surfaceFg
                    onClicked: root.toggleCollapsed(row.modelData.app)
                }

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: Appearance.s(6)
                    anchors.verticalCenter: parent.verticalCenter
                    text: `${Math.max(0, row.groupCount - root.collapseAt)} more…`
                    color: Theme.surfaceFgDim
                    font.pixelSize: Appearance.font.size.small
                }
            }
        }

        // Thin scroll indicator — only while there's more than fits.
        // Explicitly parented to the viewport: children declared inside a
        // Flickable get reparented to contentItem and scroll away with it.
        Rectangle {
            parent: list
            anchors.right: parent.right
            anchors.rightMargin: Appearance.s(2)
            width: Appearance.s(3)
            radius: width / 2
            color: Qt.alpha(Theme.surfaceFg, 0.28)
            visible: list.interactive
            height: list.height * (list.height / Math.max(list.contentHeight, 1))
            y: list.contentY * (list.height / Math.max(list.contentHeight, 1))
        }
    }

    // Keyboard nav, driven by the Popouts FocusScope: arrows select, Enter
    // opens (the card's default action / expand, or an app's collapsed run),
    // Delete dismisses. Headers are skipped — there's nothing to activate on
    // one, and stopping on them would double the presses to cross a list.
    function navMove(d: int): void {
        if (list.count === 0)
            return;
        // With no selection yet, start just *outside* the list: row 0 is always
        // an app header now, so seeding at 0 and bailing on "header at an end"
        // meant the first arrow press could never get past it and the
        // highlight never appeared at all.
        let i = list.currentIndex < 0 ? (d > 0 ? -1 : list.count) : list.currentIndex;
        for (let step = 0; step <= list.count; step++) {
            const next = Math.max(0, Math.min(list.count - 1, i + d));
            // The clamp stopped moving: nothing selectable that way.
            if (next === i)
                return;
            i = next;
            if (root.rows[i]?.kind !== "header")
                break;
        }
        // Ran out of rows without finding one — don't park on a header.
        if (root.rows[i]?.kind === "header")
            return;
        list.currentIndex = i;
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
    }

    function navActivate(): void {
        list.currentItem?.activate();
    }

    function navRemove(): void {
        list.currentItem?.dismiss();
    }
}
