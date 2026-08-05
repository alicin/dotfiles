pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Open windows, most-recently-focused first — the one fact Hyprland keeps but
// never hands out. `hyprctl clients` is in stacking/creation order, and
// Hyprland.toplevels is in whatever order the IPC filled it, so both the
// launcher's window search and the overview's Alt-Tab used to offer "the
// window you were just in" somewhere arbitrary in the list.
//
// The stack is fed by activewindowv2, which fires for *every* focus change
// including the ones the shell itself causes, so it stays true without anyone
// having to remember to update it.
Singleton {
    id: root

    // Bare hex addresses ("55d53e2e4e10"), most recent first. Bounded only by
    // the window count: entries for closed windows are dropped as they go.
    property var mru: []

    // Hyprland event addresses have no 0x; HyprlandToplevel.lastIpcObject does.
    // Everything is compared through this.
    function key(addr: var): string {
        return ((addr ?? "") + "").replace(/^0x/, "").toLowerCase();
    }

    function keyOf(toplevel: var): string {
        return root.key(toplevel?.address ?? toplevel?.lastIpcObject?.address ?? "");
    }

    function touch(addr: string): void {
        const k = root.key(addr);
        if (!k)
            return;
        // Rebuild rather than splice in place: `mru` feeds derived list
        // properties, and a mutation they can't see is a stale sort order.
        root.mru = [k, ...root.mru.filter(a => a !== k)];
    }

    function forget(addr: string): void {
        const k = root.key(addr);
        root.mru = root.mru.filter(a => a !== k);
    }

    // Where a window sits in the focus history; unseen windows sort last
    // (they were open before the shell started and haven't been touched since).
    function rank(toplevel: var): int {
        const i = root.mru.indexOf(root.keyOf(toplevel));
        return i < 0 ? 1e6 : i;
    }

    // Every real window, most-recently-focused first. Special workspaces
    // (scratchpad, void) are included on purpose — "where did that terminal
    // go" is exactly when you reach for a window switcher.
    readonly property var list: {
        root.rev; // re-evaluate on title/open/close churn
        return Hyprland.toplevels.values.filter(t => t.workspace !== null).sort((a, b) => root.rank(a) - root.rank(b));
    }

    // Titles change constantly and HyprlandToplevel.title is notifiable, but a
    // *list* built from them is not re-evaluated by a member's change alone.
    property int rev: 0

    // By address, re-resolved at call time: a row in the launcher's cache can
    // outlive the window it was built from (Hyprland reuses addresses, and
    // Quickshell deletes the toplevel outright on closewindow), and a closure
    // holding the dead object would silently do nothing.
    function focus(toplevel: var): void {
        root.focusAddress(root.keyOf(toplevel));
    }

    function focusAddress(addr: string): void {
        const key = root.key(addr);
        if (!key)
            return;
        const live = Hyprland.toplevels.values.find(t => root.keyOf(t) === key);
        if (!live)
            return;
        // Focusing a window on a special workspace does not pull that
        // workspace up, so the window would be "focused" and invisible. But
        // the dispatcher is a *toggle*: firing it at a scratchpad that is
        // already showing would put it away again and hide the very window
        // being focused, so ask first.
        const ws = live.workspace;
        if (ws && ws.id < 0 && ws.name) {
            const name = `${ws.name}`;
            const showing = Hyprland.monitors.values.some(m => (m.lastIpcObject?.specialWorkspace?.name ?? "") === name);
            // The unnamed scratchpad is called exactly "special", with no
            // colon — stripping a "special:" prefix leaves it as "special",
            // which names a *different* workspace (special:special) and
            // toggles that one instead.
            if (!showing)
                Hyprland.dispatch(`hl.dsp.workspace.toggle_special("${name === "special" ? "" : name.replace(/^special:/, "")}")`);
        }
        Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${key}" })`);
        root.touch(key);
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            const n = event.name;
            if (n === "activewindowv2")
                root.touch(event.data);
            else if (n === "closewindow") {
                root.forget(event.data);
                root.rev++;
            } else if (n === "openwindow" || n === "windowtitlev2" || n === "movewindowv2")
                root.rev++;
        }
    }

    // The shell can start (or reload) long after the session — seed the stack
    // with whatever is focused now so the very first Alt-Tab has somewhere to
    // go, instead of the list being unordered until you focus two windows.
    Component.onCompleted: {
        Hyprland.refreshToplevels();
        if (Hyprland.activeToplevel)
            root.touch(root.keyOf(Hyprland.activeToplevel));
    }
}
