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

    // Toasts hide while a bar popout covers the same top-right corner, and
    // while a capture is pending — a toast is exactly the sort of thing you
    // don't want immortalised in a screenshot.
    readonly property bool popupsHidden: menuOpen || Capture.hidingUi

    readonly property int count: list.length
    readonly property bool dnd: persist.dnd

    function toggleDnd(): void {
        persist.dnd = !persist.dnd;
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

    // Notifications survive config reloads inside the server (keepOnReload);
    // re-adopt them into our wrapper list when the singleton reinitializes.
    Component.onCompleted: {
        const existing = server.trackedNotifications.values;
        if (existing.length > 0)
            root.list = existing.map(n => ({
                n,
                at: Date.now()
            }));
    }

    PersistentProperties {
        id: persist

        reloadableId: "qshellNotifs"

        property bool dnd: false
    }

    NotificationServer {
        id: server

        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notif => {
            notif.tracked = true;
            root.now = Date.now();
            const w = {
                n: notif,
                at: Date.now()
            };
            root.list = [w, ...root.list].slice(0, 80);
            if (!persist.dnd)
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
