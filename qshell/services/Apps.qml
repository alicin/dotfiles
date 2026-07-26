pragma Singleton

import Quickshell

// Desktop entry list + fuzzy search for the launcher.
Singleton {
    id: root

    // Plain JS array (not list<DesktopEntry>) so it can feed ScriptModel.values.
    readonly property var all: [...DesktopEntries.applications.values].filter(e => !e.noDisplay).sort((a, b) => a.name.localeCompare(b.name))

    function launch(entry: DesktopEntry): void {
        entry.execute();
    }

    // Icon for a HyprlandToplevel. lastIpcObject can be null for windows
    // opened after load (hydration race) — the wayland appId is always there.
    function toplevelIcon(toplevel: var): string {
        const cls = ((toplevel?.lastIpcObject?.class || toplevel?.wayland?.appId) ?? "") + "";
        const entry = cls ? (DesktopEntries.byId(cls) ?? DesktopEntries.heuristicLookup(cls)) : null;
        const name = entry?.icon;
        return (name && Quickshell.iconPath(name, true)) || Quickshell.iconPath("application-x-executable", true) || "";
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
