pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Notification daemon. Tracks every notification (wrapped with its arrival
// time), and keeps the subset currently shown as popups. Wrappers die when
// the notification leaves the server's tracked model (dismissed/expired/
// closed by the app).
Singleton {
    id: root

    // [{ n: Notification, at: ms }]
    property var list: []
    property var popups: []
    property real now: Date.now()

    // Written by Popouts; with several screens the last writer wins, which is
    // fine for a hide flag.
    property bool menuOpen: false

    // Marking seen shrinks the bell badge, and a bar relayout under a parked
    // cursor while hover-slide is armed reads as a fresh hover and switches
    // menus by itself — so the actual write waits until every bar menu is
    // closed, when the hover-slide handlers are all disarmed.
    property bool seenPending: false

    // What the bar actually renders: `unseen` latched while a menu is open,
    // in BOTH directions — dismissing (or receiving) notifications mid-menu
    // would otherwise resize the bell module and cause the same
    // relayout-as-hover self-switch that seenPending guards against.
    property int badgeUnseen: 0

    onUnseenChanged: {
        if (!menuOpen)
            badgeUnseen = unseen;
    }

    onMenuOpenChanged: {
        if (!menuOpen) {
            if (seenPending) {
                seenPending = false;
                markSeen();
            }
            badgeUnseen = unseen;
        }
    }

    function requestSeen(): void {
        if (menuOpen)
            seenPending = true;
        else
            markSeen();
    }

    // Toasts hide while a bar popout covers the same top-right corner, and
    // while a capture is pending — a toast is exactly the sort of thing you
    // don't want immortalised in a screenshot.
    readonly property bool popupsHidden: menuOpen || Capture.hidingUi

    readonly property int count: list.length
    readonly property real lastSeenAt: persist.lastSeen
    // What the bar badge shows: notifications that arrived since the bell menu
    // was last open. Badging `count` meant the number never went down short of
    // Clear, and a badge that permanently reads "23" carries no signal.
    readonly property int unseen: list.filter(w => w.at > persist.lastSeen).length
    readonly property bool dnd: persist.dnd

    function toggleDnd(): void {
        persist.dnd = !persist.dnd;
    }

    function markSeen(): void {
        persist.lastSeen = Date.now();
    }

    function dropPopup(w: var): void {
        root.popups = root.popups.filter(p => p !== w);
    }

    // Actions on notifications the *shell* posts (screenshots, recordings) are
    // carried out here rather than over DBus. Sending an action back to the
    // client is useless for these: whatever posted the notification exits
    // immediately, so by the time you open the notification center the button
    // has nobody to talk to and does nothing at all.
    //
    // The identifier is a verb and nothing else — the path it acts on is the
    // notification's own body, i.e. the path the card is already showing you.
    // So "Open" can't be talked into doing anything other than what it says,
    // even by an app that lies about its name.
    //
    // Returns true when it handled the action, so the caller can skip invoke().
    function runAction(notif: var, identifier: string): bool {
        if (!notif || notif.appName !== "qshell")
            return false;

        const path = notif.body;
        if (identifier === "qshell-open") {
            Quickshell.execDetached(["xdg-open", path]);
            return true;
        }
        if (identifier === "qshell-reveal") {
            // ShowItems highlights the file in whatever file manager is
            // registered, which beats dumping you in a folder of 400
            // screenshots. Falls back to opening the directory.
            Quickshell.execDetached(["sh", "-c", `
                gdbus call --session --dest org.freedesktop.FileManager1 \
                    --object-path /org/freedesktop/FileManager1 \
                    --method org.freedesktop.FileManager1.ShowItems "['file://$1']" "" \
                    >/dev/null 2>&1 || xdg-open "$(dirname "$1")"
            `, "qshell-reveal", path]);
            return true;
        }
        return false;
    }

    function clearAll(): void {
        const all = [...root.list];
        root.list = [];
        root.popups = [];
        all.forEach(w => w.n.dismiss());
    }

    PersistentProperties {
        id: persist

        reloadableId: "qshellNotifs"

        property bool dnd: false
        property real lastSeen: 0
    }

    NotificationServer {
        id: server

        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true

        // Notifications survive config reloads inside the server
        // (keepOnReload) and are *replayed* through this handler on the next
        // load, flagged lastGeneration — there is no separate re-adopt hook
        // (an onCompleted read of trackedNotifications sees an empty list;
        // that was tried). Replays are stamped as already-seen and skip the
        // popups, or every reload would relight the badge and re-toast up to
        // five old notifications.
        onNotification: notif => {
            notif.tracked = true;
            root.now = Date.now();
            const w = {
                n: notif,
                at: notif.lastGeneration ? persist.lastSeen : Date.now()
            };
            root.list = [w, ...root.list].slice(0, 80);
            if (!persist.dnd && !notif.lastGeneration)
                root.popups = [...root.popups, w].slice(-5);
        }
    }

    Connections {
        target: server.trackedNotifications

        function onValuesChanged() {
            const alive = server.trackedNotifications.values;
            root.list = root.list.filter(w => alive.includes(w.n));
            root.popups = root.popups.filter(w => alive.includes(w.n));
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.list.length > 0
        onTriggered: root.now = Date.now()
    }
}
