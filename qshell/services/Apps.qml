pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config

// Desktop entry list + fuzzy search for the launcher, and the window -> icon
// lookup the workspace pills and the overview share.
Singleton {
    id: root

    // Plain JS array (not list<DesktopEntry>) so it can feed ScriptModel.values.
    readonly property var all: [...DesktopEntries.applications.values].filter(e => !e.noDisplay).sort((a, b) => a.name.localeCompare(b.name))

    // pid -> argv[0] basename. Icon sources re-evaluate on every workspace
    // change, so the /proc read is cached; only a recycled pid can go stale.
    property var exeByPid: ({})

    // Launch counts + last-launch times, persisted to the Quickshell state
    // dir (NOT settings.json — that lives in the dotfiles repo and this is
    // churn, not configuration). Drives the empty-query ordering and a small
    // ranked-search boost: the five daily apps used to sit alphabetized under
    // everything else, always needing typing.
    function frecency(id: string): real {
        const u = usage.apps[id];
        if (!u)
            return 0;
        const days = (Date.now() - u.last) / 86400000;
        // Log-damped count with a ~2-week recency half-life: heavy use keeps
        // an app up, but abandoning it lets it sink rather than squat forever.
        return Math.log1p(u.n) * Math.exp(-days / 14);
    }

    // Bookkeeping without the launch, for the paths that start an app some
    // other way (a desktop entry's own action — "New Private Window" — is
    // still that app being used).
    // Launches recorded but not yet merged into the persisted store. A plain
    // JS object on purpose: reading a JsonAdapter `var` property hands back a
    // COPY across the C++ boundary, so the old "mutate usage.apps in place"
    // pattern wrote into a temporary and the store stayed `{}` forever — the
    // launcher looked alphabetical because every frecency was 0. Staging here
    // and REASSIGNING at flush both persists and keeps the original design
    // goal: no re-sort while the panel is still fading out.
    property var pendingUsage: ({})

    function record(entry: DesktopEntry): void {
        if (!entry)
            return;
        const cur = root.pendingUsage[entry.id] ?? usage.apps[entry.id] ?? {
            n: 0,
            last: 0
        };
        root.pendingUsage[entry.id] = {
            n: cur.n + 1,
            last: Date.now()
        };
    }

    function launch(entry: DesktopEntry): void {
        // A destroyed DesktopEntry reads as null in QML, and this used to throw
        // "Cannot read property 'execute' of null" from a stale cached row —
        // noisy in the log and, more to the point, a silent no-op to whoever
        // pressed Enter. Callers now re-resolve by id (see Search.appRow), but
        // refuse the null here too rather than trusting every future caller.
        if (!entry)
            return;
        // The launch itself is never skipped, whatever the store is doing.
        root.record(entry);
        entry.execute();
    }

    // Re-sorts every consumer and persists (adapterUpdated → writeAdapter).
    // The ready-gate lives HERE, not in record(): a launch made before the
    // store loads now waits in pendingUsage instead of being dropped, and
    // merging into the loaded map can never clobber history with defaults.
    function flushUsage(): void {
        if (!usageFile.ready || Object.keys(root.pendingUsage).length === 0)
            return;
        usage.apps = Object.assign({}, usage.apps, root.pendingUsage);
        root.pendingUsage = {};
    }

    FileView {
        id: usageFile

        property bool ready: false

        path: Quickshell.statePath("launcher-usage.json")
        // Temp-file + rename: a crash mid-write must never replace the last
        // good history with a truncated file.
        atomicWrites: true
        onAdapterUpdated: writeAdapter()
        onLoaded: ready = true
        onLoadFailed: error => {
            // Only a genuinely missing file gets defaults written over it —
            // any other failure must not let the next write clobber data.
            if (error === FileViewError.FileNotFound)
                writeAdapter();
            ready = true;
        }

        adapter: JsonAdapter {
            id: usage

            // id -> { n: launches, last: ms }
            property var apps: ({})
        }
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
        // Bounded: this grew for the whole session, and a recycled pid then
        // served the previous process's name for icon lookup. A wholesale
        // reset is fine — it is a cache over /proc, one read rebuilds it.
        if (Object.keys(root.exeByPid).length > 256)
            root.exeByPid = {};
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
        // Empty query: frecent apps first, the rest alphabetical under them.
        if (!q)
            return [...root.all].sort((a, b) => (frecency(b.id) - frecency(a.id)) || a.name.localeCompare(b.name));

        return root.all.map(e => {
            const name = scoreText(e.name, q);
            const alt = Math.max(scoreText(e.genericName, q), scoreText(e.comment, q), scoreText(e.keywords, q));
            // Frecency is a capped nudge among REAL matches only — boosting
            // the -1 no-match sentinel let daily apps pass the score filter
            // for queries they don't match at all.
            const base = Math.max(name * 2, alt);
            const score = base > 0 ? base + Math.min(4, frecency(e.id)) : base;
            return {
                entry: e,
                score
            };
        }).filter(r => r.score > 0).sort((a, b) => b.score - a.score).slice(0, 48).map(r => r.entry);
    }

    // The scorer knows which characters matched; render them. Rich-text
    // markup over the app name — accent on the matched subsequence — so a
    // fuzzy hit like "gcr" → "Google ChRome" reads as a match, not noise.
    function markMatches(text: string, query: string): string {
        const esc = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        const q = query.trim().toLowerCase();
        if (!q)
            return esc(text);
        const t = text.toLowerCase();
        let out = "";
        let pos = 0;
        for (let qi = 0; qi < q.length; qi++) {
            const idx = t.indexOf(q[qi], pos);
            // The name alone doesn't contain the subsequence (matched via
            // comment/keywords) — no marks to draw.
            if (idx === -1)
                return esc(text);
            out += esc(text.slice(pos, idx)) + `<font color="${Theme.accent}">${esc(text[idx])}</font>`;
            pos = idx + 1;
        }
        return out + esc(text.slice(pos));
    }
}
