pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// Notification daemon. Tracks every notification (wrapped with its arrival
// time), and keeps the subset currently shown as popups. Wrappers die when
// the notification leaves the server's tracked model (dismissed/expired/
// closed by the app).
//
// History outlives the process: entries are mirrored to a state file and read
// back as *ghosts* — inert wrappers with the same shape and no live
// notification behind them. A shell restart used to empty the notification
// centre, which is the one moment you're most likely to go looking in it.
Singleton {
    id: root

    // [{ n: Notification | ghost, at: ms, ghost?: bool, muted?: bool }]
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
    // don't want immortalised in a screenshot. (A live *recording* is handled
    // per-screen in NotificationPopups, which knows where the region is.)
    readonly property bool popupsHidden: menuOpen || Capture.hidingUi

    readonly property int count: list.length
    readonly property real lastSeenAt: persist.lastSeen
    // What the bar badge shows: notifications that arrived since the bell menu
    // was last open. Badging `count` meant the number never went down short of
    // Clear, and a badge that permanently reads "23" carries no signal. Muted
    // apps are excluded — the whole point of muting one is that it stops
    // asking for attention.
    readonly property int unseen: list.filter(w => w.at > persist.lastSeen && !w.muted).length
    readonly property bool dnd: persist.dnd

    // ── Per-app muting ──
    // Persisted to the state file rather than PersistentProperties: this is a
    // standing decision about an app, and losing it on restart would make it
    // indistinguishable from the app having gone quiet on its own.
    readonly property var muted: state.muted ?? []

    function isMuted(app: string): bool {
        return app !== "" && root.muted.includes(app);
    }

    function toggleMute(app: string): void {
        if (!app)
            return;
        state.muted = root.isMuted(app) ? root.muted.filter(a => a !== app) : [...root.muted, app];
        stateFile.writeAdapter();
    }

    // ── Grouping ──
    // [{ app, items: [wrapper], muted }] in newest-first order of each app's
    // most recent notification, which keeps a chatty app from burying the rest
    // while still surfacing whoever spoke last.
    readonly property var grouped: {
        const groups = [];
        const byApp = ({});
        for (const w of root.list) {
            const app = w.n?.appName || "notification";
            if (!(app in byApp)) {
                byApp[app] = {
                    app,
                    items: [],
                    muted: root.isMuted(app)
                };
                groups.push(byApp[app]);
            }
            byApp[app].items.push(w);
        }
        return groups;
    }

    // Read live by the menu's header rows, so a cached row object can keep its
    // identity (which is what stops the whole list rebuilding on every
    // arrival) while the number it shows moves.
    function groupCount(app: string): int {
        return root.list.filter(w => (w.n?.appName || "notification") === app).length;
    }

    function toggleDnd(): void {
        persist.dnd = !persist.dnd;
    }

    // Mirrored into the state file as well as PersistentProperties: the
    // latter survives a config reload but not a restart, and every restored
    // ghost carries its real arrival time — so a watermark of 0 made the whole
    // restored history count as unseen and the badge came back reading "40".
    function markSeen(): void {
        persist.lastSeen = Date.now();
        state.lastSeen = persist.lastSeen;
        if (stateFile.loaded)
            stateFile.writeAdapter();
    }

    function dropPopup(w: var): void {
        root.popups = root.popups.filter(p => p !== w);
        root.retire(w);
    }

    // A transient notification lives only in `popups` — when its toast
    // retires without an explicit dismissal, the server would otherwise keep
    // the object tracked forever and the sender never hears
    // NotificationClosed. Anything still in `list` stays: the bell menu owns
    // its lifetime.
    function retire(w: var): void {
        if (!root.list.includes(w))
            w.n?.expire();
    }

    // The bell menu absorbing pending toasts must retire the transient ones
    // too, not just empty the array.
    function absorbPopups(): void {
        const gone = root.popups;
        root.popups = [];
        gone.forEach(w => root.retire(w));
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
        if (identifier === "qshell-edit") {
            Capture.annotate(path);
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
        // Popup-only (transient) wrappers aren't in `list` and would leak.
        const orphans = root.popups.filter(w => !all.includes(w));
        root.list = [];
        root.popups = [];
        orphans.forEach(w => w.n?.expire());
        // Ghosts have no server object; their dismiss() is a local removal
        // from a list that is already empty, which is harmless.
        all.forEach(w => w.n?.dismiss());
    }

    // Newest first, so "dismiss the latest" over IPC means the one that just
    // interrupted you.
    function dismissLatest(): bool {
        const w = root.popups[root.popups.length - 1] ?? root.list[0];
        if (!w)
            return false;
        w.n?.dismiss();
        return true;
    }

    // ── History persistence ──

    // Ghosts are removed straight out of the list: there's no server object to
    // tell about it.
    function forget(w: var): void {
        root.list = root.list.filter(x => x !== w);
    }

    function sameNotif(a: var, b: var): bool {
        return (a?.appName ?? "") === (b?.appName ?? "") && (a?.summary ?? "") === (b?.summary ?? "") && (a?.body ?? "") === (b?.body ?? "");
    }

    // A wrapper that renders exactly like a live one and does nothing else.
    // NotificationCard reads everything through `?.`, so the only member that
    // has to actually work is dismiss().
    function ghostFor(e: var): var {
        const g = ({
                appName: e.appName ?? "",
                summary: e.summary ?? "",
                body: e.body ?? "",
                appIcon: e.appIcon ?? "",
                image: e.image ?? "",
                desktopEntry: e.desktopEntry ?? "",
                urgency: e.urgency ?? NotificationUrgency.Normal,
                actions: [],
                transient: false,
                resident: false,
                hasInlineReply: false,
                expire: function () {}
            });
        const w = ({
                n: g,
                at: e.at ?? Date.now(),
                ghost: true,
                muted: root.isMuted(g.appName)
            });
        g.dismiss = function () {
            root.forget(w);
        };
        return w;
    }

    function serialize(w: var): var {
        const n = w.n;
        return ({
                appName: n?.appName ?? "",
                summary: n?.summary ?? "",
                body: n?.body ?? "",
                // The image hint is a live pixmap behind a process-local URI —
                // it means nothing to the next process. appIcon is a path or an
                // icon name, and survives.
                appIcon: n?.appIcon ?? "",
                desktopEntry: n?.desktopEntry ?? "",
                urgency: n?.urgency ?? NotificationUrgency.Normal,
                at: w.at
            });
    }

    // Debounced: a burst of five notifications should write the file once.
    Timer {
        id: saveDebounce

        interval: 1500
        onTriggered: {
            state.history = root.list.slice(0, 40).map(w => root.serialize(w));
            state.lastSeen = persist.lastSeen;
            stateFile.writeAdapter();
        }
    }

    onListChanged: {
        if (stateFile.loaded)
            saveDebounce.restart();
    }

    FileView {
        id: stateFile

        // Set once the file has been read (or found missing), so the first
        // load can't be clobbered by a save triggered while it's still in
        // flight.
        property bool loaded: false

        path: Quickshell.statePath("notifications.json")
        watchChanges: false
        atomicWrites: true

        onLoaded: {
            // The seen watermark comes back before the history does, so
            // restored entries are measured against it rather than against 0.
            // Max, not assignment: a reload's PersistentProperties value is
            // newer than anything on disk.
            persist.lastSeen = Math.max(persist.lastSeen, state.lastSeen ?? 0);
            // Anything the server already replayed wins — the ghost would be
            // the same notification twice.
            const fresh = (state.history ?? []).filter(e => !root.list.some(w => root.sameNotif(w.n, e))).map(e => root.ghostFor(e));
            root.list = [...root.list, ...fresh].sort((a, b) => b.at - a.at).slice(0, 80);
            stateFile.loaded = true;
        }

        // A missing file on first run is the normal case, not an error.
        //
        // Any *other* failure (unparseable JSON, a truncated write) still
        // unblocks saving: leaving `loaded` false would mean history silently
        // stopped persisting until someone noticed and deleted the file by
        // hand. The next save overwrites whatever was unreadable.
        onLoadFailed: err => {
            stateFile.loaded = true;
            if (err === FileViewError.FileNotFound)
                stateFile.writeAdapter();
        }

        adapter: JsonAdapter {
            id: state

            property var history: []
            property var muted: []
            property real lastSeen: 0
        }
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
        // Advertised so chat clients send a reply box rather than a "Reply"
        // action that opens the whole app.
        inlineReplySupported: true

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
            const muted = root.isMuted(notif.appName);
            const w = ({
                    n: notif,
                    at: notif.lastGeneration ? persist.lastSeen : Date.now(),
                    muted
                });
            // Transient notifications (volume spam, progress ticks) show as
            // toasts but skip the history — apps set the hint precisely
            // because the daemon should show-and-forget them. Critical
            // pierces DND: a battery-critical alert filed silently into
            // history defeats both features at once. Muting an app stops its
            // toasts only; the history is where you go to check what you told
            // to be quiet.
            const inList = !notif.transient;
            // A capture the floating thumbnail is already showing doesn't also
            // get a toast — same file, same second, two announcements stacked
            // in the same corner. History still gets it, which is where you go
            // looking for the path an hour later.
            const onThumb = notif.appName === "qshell" && notif.body !== "" && notif.body === Capture.lastCapture && Date.now() - Capture.lastCaptureAt < 5000;
            const inPopups = (!persist.dnd || notif.urgency === NotificationUrgency.Critical) && !notif.lastGeneration && !muted && !onThumb;
            if (inList) {
                // A replay is the same notification as the ghost that was
                // saved for it — keep the live one, which can still be
                // dismissed and still carries its actions.
                const survivors = notif.lastGeneration ? root.list.filter(x => !(x.ghost && root.sameNotif(x.n, notif))) : root.list;
                root.list = [w, ...survivors].slice(0, 80);
            }
            if (inPopups) {
                const next = [...root.popups, w];
                // Wrappers the cap evicts leave the screen for good — retire
                // them, or capped-out transients leak in the server.
                next.slice(0, Math.max(0, next.length - 5)).forEach(p => root.retire(p));
                root.popups = next.slice(-5);
            }
            // Neither container (DND-suppressed transient, transient replay):
            // nothing will ever show or dismiss it — close it out now.
            if (!inList && !inPopups)
                notif.expire();
        }
    }

    Connections {
        target: server.trackedNotifications

        function onValuesChanged() {
            const alive = server.trackedNotifications.values;
            // Ghosts are exempt: they were never in the server's model and
            // this filter would drop the entire restored history on the first
            // live notification.
            root.list = root.list.filter(w => w.ghost || alive.includes(w.n));
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
