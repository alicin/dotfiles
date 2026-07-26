pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Desktop entry list + fuzzy search for the launcher, and the window -> icon
// lookup the workspace pills and the overview share.
Singleton {
    id: root

    // Plain JS array (not list<DesktopEntry>) so it can feed ScriptModel.values.
    readonly property var all: [...DesktopEntries.applications.values].filter(e => !e.noDisplay).sort((a, b) => a.name.localeCompare(b.name))

    // pid -> argv[0] basename. Icon sources re-evaluate on every workspace
    // change, so the /proc read is cached; only a recycled pid can go stale.
    property var exeByPid: ({})

    function launch(entry: DesktopEntry): void {
        entry.execute();
    }

    // Blocking, always-fresh reads: /proc is memory-backed (~20µs a read), and
    // an async one would leave the icon generic until something else happens
    // to re-evaluate the binding.
    FileView {
        id: procFile

        blockLoading: true
        blockAllReads: true
        printErrors: false // the process can be gone by the time we look
    }

    // Hyprland fills lastIpcObject (class, pid) only for windows that already
    // existed when the shell started; anything opened later needs a refetch,
    // or it keeps the generic icon for its whole life.
    Timer {
        id: hydrate

        interval: 60
        onTriggered: Hyprland.refreshToplevels()
        // Windows that opened while the shell was down (or between reloads)
        // never fire an openwindow we can see.
        Component.onCompleted: start()
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "openwindow")
                hydrate.restart();
        }
    }

    // Executable behind a pid — "kitty" for `kitty --class=com.ali.floating_shell`.
    function exeName(pid: int): string {
        if (!pid)
            return "";

        const cached = root.exeByPid[pid];
        if (cached !== undefined)
            return cached;

        // cmdline is NUL-separated, except for the Electron/Chrome family,
        // which rewrites the whole block in place with spaces. comm (truncated
        // to 15 chars) covers the rare process that exposes an empty one.
        procFile.path = `/proc/${pid}/cmdline`;
        let argv0 = procFile.text().split("\0")[0].split(" ")[0];
        if (!argv0) {
            procFile.path = `/proc/${pid}/comm`;
            argv0 = procFile.text().trim();
        }

        const name = argv0.slice(argv0.lastIndexOf("/") + 1);
        root.exeByPid[pid] = name;
        return name;
    }

    function entryFor(name: string): var {
        return name ? (DesktopEntries.byId(name) ?? DesktopEntries.heuristicLookup(name)) : null;
    }

    // Icon for a HyprlandToplevel. lastIpcObject can be null for windows
    // opened after load (hydration race) — the wayland appId is always there.
    function toplevelIcon(toplevel: var): string {
        const ipc = toplevel?.lastIpcObject;
        const cls = ((ipc?.class || toplevel?.wayland?.appId) ?? "") + "";
        // A window launched under a custom class has no desktop entry of its
        // own, so fall back to the process behind it.
        const entry = entryFor(cls) ?? entryFor(exeName(ipc?.pid ?? 0));
        const name = entry?.icon;
        return (name && Quickshell.iconPath(name, true)) || Quickshell.iconPath(cls, true) || Quickshell.iconPath("application-x-executable", true) || "";
    }

    // Subsequence fuzzy score: every query char must appear in order.
    // Bonuses for word starts and consecutive runs, mild penalty for gaps.
    function scoreText(text: string, query: string): real {
        if (!text)
            return -1;
        const t = text.toLowerCase();
        const q = query.toLowerCase();
        let score = 0;
        let ti = 0;
        let lastMatch = -2;
        for (let qi = 0; qi < q.length; qi++) {
            const idx = t.indexOf(q[qi], ti);
            if (idx === -1)
                return -1;
            score += 1;
            if (idx === 0 || " -_./".includes(t[idx - 1]))
                score += 3; // word start
            if (idx === lastMatch + 1)
                score += 2; // consecutive
            score -= (idx - ti) * 0.05; // gap penalty
            lastMatch = idx;
            ti = idx + 1;
        }
        if (t === q)
            score += 6;
        if (t.startsWith(q))
            score += 3;
        return score;
    }

    function search(query: string): var {
        const q = query.trim();
        if (!q)
            return root.all;

        return root.all.map(e => {
            const name = scoreText(e.name, q);
            const alt = Math.max(scoreText(e.genericName, q), scoreText(e.comment, q), scoreText(e.keywords, q));
            const score = Math.max(name * 2, alt);
            return {
                entry: e,
                score
            };
        }).filter(r => r.score > 0).sort((a, b) => b.score - a.score).slice(0, 48).map(r => r.entry);
    }
}
