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

    // Toasts hide while a bar popout menu is open (they share the top-right).
    // Written by Popouts; with several screens the last writer wins, which is
    // fine for a hide flag.
    property bool popupsHidden: false

    readonly property int count: list.length
    readonly property bool dnd: persist.dnd

    function toggleDnd(): void {
        persist.dnd = !persist.dnd;
    }

    function dropPopup(w: var): void {
        root.popups = root.popups.filter(p => p !== w);
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
