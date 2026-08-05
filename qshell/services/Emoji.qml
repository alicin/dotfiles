pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// The launcher's `:` mode. The table is `data/emoji.json` — the installed
// emoji font's cmap intersected with the Unicode character database, so every
// entry both has a name to search by and a glyph that renders here (see
// scripts/gen-emoji.py).
//
// Loaded lazily: 1400 entries is 49KB of JSON that most sessions never ask
// for, so nothing touches the disk until someone types `:`.
Singleton {
    id: root

    property var all: []
    property bool loading: false

    readonly property bool loaded: root.all.length > 0

    // Most-recently-picked characters, newest first — the empty-`:` list.
    // Codepoint order otherwise means every session starts at "‼".
    readonly property var recent: state.recent ?? []

    function ensure(): void {
        if (root.loaded || root.loading)
            return;
        root.loading = true;
        table.path = Quickshell.shellPath("data/emoji.json");
    }

    function pick(ch: string): void {
        // `--` for the same reason the calculator needs it: wl-copy takes its
        // payload as argv and getopt would eat anything starting with a dash.
        Quickshell.execDetached(["wl-copy", "--", ch]);
        state.recent = [ch, ...root.recent.filter(c => c !== ch)].slice(0, 40);
    }

    function search(query: string): var {
        const q = query.trim().toLowerCase();
        if (!q) {
            // Recents, then the ones carrying hand-written aliases — that set
            // is exactly the everyday emoji, and it is what an empty picker
            // should open on. Codepoint order alone starts at "‼", "™", "ℹ",
            // which is a fair description of the whole Unicode block and a
            // terrible first screen. Everything else follows in table order
            // (smileys → gestures → objects), which browses fine.
            const seen = new Set(root.recent);
            const rec = root.recent.map(c => root.all.find(e => e.c === c)).filter(e => e);
            const popular = root.all.filter(e => e.k && !seen.has(e.c));
            const shown = new Set([...seen, ...popular.map(e => e.c)]);
            return [...rec, ...popular, ...root.all.filter(e => !shown.has(e.c))];
        }
        return root.all.map(e => {
            // The alias words are what people actually type ("thumbsup",
            // "lol"), so they score as strongly as the formal Unicode name.
            const byName = Apps.scoreText(e.n, q);
            const byAlias = e.k ? Apps.scoreText(e.k, q) : -1;
            return {
                e,
                score: Math.max(byName, byAlias)
            };
        }).filter(r => r.score > 0).sort((a, b) => b.score - a.score).slice(0, 64).map(r => r.e);
    }

    FileView {
        id: table

        // Set by ensure(); an unset path never reads.
        onLoaded: {
            try {
                root.all = JSON.parse(text());
            } catch (e) {
                root.all = [];
            }
            root.loading = false;
        }
        onLoadFailed: root.loading = false
    }

    FileView {
        path: Quickshell.statePath("emoji-recent.json")
        atomicWrites: true
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        adapter: JsonAdapter {
            id: state

            property var recent: []
        }
    }
}
