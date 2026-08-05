pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config
import qs.services

// Clipboard history on top of cliphist — the same store the old
// `cliphist list | wofi --show dmenu | cliphist decode | wl-copy` binding used,
// so history carries over and `wl-paste --watch cliphist store` (started in
// hyprland's startup.lua) stays the only writer.
//
// Pins are the one thing kept outside it: everything cliphist can name an
// entry by dies with the entry, so a pinned row keeps its own copy of the
// bytes and never asks cliphist for anything again.
Singleton {
    id: root

    // [{ id, preview, image, meta, kind, dims, size, paths, truncated }] —
    // newest first, as cliphist lists them.
    property var entries: []

    // False until the first listing lands — the picker shows nothing instead
    // of flashing "Clipboard is empty" during the round trip.
    property bool loaded: false

    // id -> full decoded text of truncated TEXT entries. cliphist previews
    // cap at 100 chars and a path's filename is exactly what falls off the
    // end — so the row showed "report-final.pdf" while typing "report" never
    // matched. Filled in one batched decode after each listing.
    property var fullText: ({})

    readonly property var imageExts: ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "avif", "tif", "tiff"]

    function isImagePath(p: string): bool {
        const ext = p.split(".").pop().toLowerCase();
        return root.imageExts.includes(ext);
    }

    function baseName(p: string): string {
        return p.replace(/\/+$/, "").split("/").pop();
    }

    function dirName(p: string): string {
        const cut = p.replace(/\/+$/, "").lastIndexOf("/");
        return cut > 0 ? p.slice(0, cut) : "/";
    }

    // Copied file paths arrive as plain text, so pull them apart to show the
    // filename instead of an elided absolute path. Split on a space that's
    // followed by a slash: that separates "a.pdf /home/b.pdf" into two entries
    // without breaking "Screenshot 2026-06-23 at 2.12.12 AM.png".
    function parsePaths(preview: string): var {
        const s = preview.replace(/^file:\/\//, "").trim();
        if (!s.startsWith("/") || s.includes("\n"))
            return [];
        return s.split(/ (?=\/)/).map(p => p.replace(/^file:\/\//, ""));
    }

    // Decoded image thumbnails live here, keyed by cliphist id. Under
    // XDG_RUNTIME_DIR so they're tmpfs-backed and vanish with the session —
    // clipboard contents shouldn't outlive it on disk.
    readonly property string thumbDir: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/qshell-clipthumbs`

    // Thumbnails are the full decoded originals, and XDG_RUNTIME_DIR is tmpfs
    // (i.e. RAM), so start each session clean instead of letting them pile up.
    // Also drops ids left stale by an external `cliphist wipe`.
    Component.onCompleted: Quickshell.execDetached(["sh", "-c", `rm -rf '${root.thumbDir}'`])

    function refresh(): void {
        // Not a stop-start: setting running false SIGTERMs an in-flight
        // `cliphist list`, and Quickshell then publishes whatever partial
        // stdout it had collected as if it were the whole history. A listing
        // already on its way is the listing we wanted anyway.
        if (!lister.running)
            lister.running = true;
        sourceFile.reload();
    }

    // delete reads the full "id<TAB>preview" line, so select it back out of
    // list rather than reconstructing it.
    function remove(id: string): void {
        // The thumbnail goes with it: these are full-size decodes on tmpfs,
        // i.e. RAM, and clearing forty screenshots out of the picker used to
        // free the history and keep every byte of the previews.
        Quickshell.execDetached(["sh", "-c", `cliphist list | awk -F'\\t' -v id=${id} '$1 == id' | cliphist delete; rm -f '${root.thumbDir}/${id}'`]);
        root.entries = entries.filter(e => e.id !== id);
        if (root.fullText[id] !== undefined) {
            const m = Object.assign({}, root.fullText);
            delete m[id];
            root.fullText = m;
        }
    }

    // Pins are not history — they live in their own directory under a name
    // cliphist has never heard of, so there is nothing here for this to take.
    function wipe(): void {
        Quickshell.execDetached(["cliphist", "wipe"]);
        Quickshell.execDetached(["sh", "-c", `rm -rf '${root.thumbDir}'`]);
        root.entries = [];
        // Every id in here now points at nothing.
        root.fullText = {};
    }

    function search(query: string, filter: string): var {
        const pool = filter && filter !== "all" ? root.items.filter(e => (filter === "pinned" ? e.pinned === true : root.kindOf(e) === filter)) : root.items;
        const q = query.trim();
        if (!q)
            return pool;
        return pool.map(e => ({
                    e,
                    // Full text when the preview was cut — search matches what
                    // the row visibly says.
                    score: Apps.scoreText(root.entryText(e), q)
                })).filter(r => r.score > 0).sort((a, b) => (b.e.pinned ? 1 : 0) - (a.e.pinned ? 1 : 0) || b.score - a.score).slice(0, 64).map(r => r.e);
    }

    // ── What a row *is* ──
    //
    // The filter bar's categories, and what each card draws. Deliberately
    // coarse: five buckets you can name at a glance beat a mime taxonomy
    // nobody wants to filter by.
    function kindOf(entry: var): string {
        if (entry.image)
            return "image";
        const text = root.entryText(entry);
        if ((entry.paths ?? []).length > 0)
            return "file";
        if (/^\s*(https?|ftp|magnet|mailto):\S+\s*$/i.test(text))
            return "link";
        // Only what Qt can actually turn into a colour. CSS rgb()/hsl() and
        // the 8-digit #RRGGBBAA form all parse as "invalid" — QColor's own
        // 8-digit form is #AARRGGBB — and the card would then hide the text in
        // favour of drawing a swatch of nothing.
        if (/^\s*#([0-9a-f]{3}|[0-9a-f]{6})\s*$/i.test(text))
            return "color";
        return "text";
    }

    // The colour a colour-valued entry names, for the swatch on its card.
    function colorOf(entry: var): color {
        return root.entryText(entry).trim();
    }

    // ── Where a row came from ──
    //
    // cliphist stores content and nothing else — no source, no timestamp. Both
    // are knowable only at the moment of the copy, which is why the wl-paste
    // watcher runs scripts/clip-store.sh instead of `cliphist store` and
    // leaves a TSV behind. Everything here degrades to blank if that file is
    // missing: it decorates cards, it does not drive them.
    property var sources: ({})

    function sourceFor(entry: var): var {
        return entry.pinned ? null : (root.sources[entry.id] ?? null);
    }

    // "now", "4m", "2h", "3d" — the clipboard's own sense of scale. Anything
    // that predates the side file has no time and says nothing.
    function ageOf(entry: var): string {
        const at = root.sourceFor(entry)?.at ?? 0;
        if (!at)
            return "";
        const secs = Math.max(0, Math.floor(Date.now() / 1000) - at);
        if (secs < 45)
            return "now";
        if (secs < 3600)
            return `${Math.round(secs / 60)}m`;
        if (secs < 86400)
            return `${Math.round(secs / 3600)}h`;
        return `${Math.round(secs / 86400)}d`;
    }

    FileView {
        id: sourceFile

        path: `${Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`}/qshell/clipboard-sources.tsv`
        // Read on every listing rather than watched: the picker asks for a
        // refresh when it opens, which is the only moment this is read at all.
        printErrors: false

        onLoaded: {
            const map = {};
            for (const line of text().split("\n")) {
                // id, seconds, class, title — all four or the row is from a
                // different shape of this file and every field after the
                // missing one would be read as the wrong thing (a window title
                // rendered as an application name, say).
                const parts = line.split("\t");
                if (parts.length !== 4)
                    continue;
                map[parts[0]] = {
                    at: parseInt(parts[1], 10) || 0,
                    cls: parts[2],
                    title: parts[3]
                };
            }
            root.sources = map;
        }
    }

    // ── Pins ──

    // The payload is copied out of cliphist and kept here, because a pin has
    // to survive the two things that happen to cliphist: a screenshot session
    // pushing entries off the end of the store, and `cliphist wipe`. Both take
    // the id with them, and an id is all cliphist can be asked for.
    readonly property string pinDir: Quickshell.statePath("clipboard-pins")

    // Rows for the pin store. A property rather than a binding over the
    // adapter because ScriptModel diffs by identity: fresh objects on every
    // re-evaluation reset the model and yank the selection out from under
    // whoever is typing.
    property var pins: []

    // Two pins inside the same millisecond would otherwise land on one file.
    property int pinSeq: 0

    // Pins first, then the history rows they were made FROM — the same entry
    // twice, one of which survives a wipe, is a coin flip nothing on screen
    // could help you win.
    //
    // Hidden by cliphist id, never by content: matching on a prefix of what a
    // row *shows* hides unrelated entries that merely start the same way, and
    // this store is full of them — two API keys for the same project share
    // their first ninety characters, and every screenshot of this monitor
    // previews as the identical `[[ binary data 660 KiB png 2560x1600 ]]`.
    // Pinning one would have made the other invisible, unsearchable and
    // undeletable. An id is exact, and re-copying the same thing earns a new
    // one — so it shows up again as history, which is the truth.
    readonly property var items: {
        const hidden = root.pins.map(p => p.srcId).filter(id => id);
        return [...root.pins, ...root.entries.filter(e => !hidden.includes(e.id))];
    }

    // The text a row actually shows: pins carry their own, history rows get
    // the batched decode when the preview was cut.
    function entryText(entry: var): string {
        return entry.pinned ? entry.preview : (root.fullText[entry.id] ?? entry.preview);
    }

    function togglePin(entry: var): void {
        if (entry.pinned)
            root.unpin(entry);
        else
            root.pin(entry);
    }

    // Queued, not run on the spot: the record may only be written once the
    // bytes are on disk, and two quick pins racing on the one Process would
    // lose the first.
    function pin(entry: var): void {
        // Held Ctrl+P repeats at ~25/s and the row does not read as pinned
        // until its payload has landed several turns later — without this you
        // get a fistful of identical pins for one keypress.
        if (pinner.current?.srcId === entry.id || pinner.queue.some(j => j.id === entry.id))
            return;
        const kind = `${entry.kind}`.toLowerCase();
        pinner.queue = [...pinner.queue,
            {
                id: entry.id,
                rec: {
                    file: `${root.pinDir}/${Date.now().toString(36)}-${root.pinSeq++}.${entry.image ? kind || "bin" : "txt"}`,
                    // Which history row this pin stands in for, so `items` can
                    // hide that one row and nothing else.
                    srcId: entry.id,
                    mime: root.pinMime(entry),
                    // The decoded text wherever we have it: a pinned path has
                    // to still read (and search) as its filename once the id
                    // behind the 100-char preview is gone.
                    preview: entry.image ? entry.preview : (root.fullText[entry.id] ?? entry.preview),
                    image: entry.image,
                    kind: entry.kind,
                    dims: entry.dims,
                    size: entry.size
                }
            }
        ];
        root.pumpPins();
    }

    function unpin(entry: var): void {
        Quickshell.execDetached(["rm", "-f", entry.file]);
        pinStore.items = (pinStore.items ?? []).filter(r => r.file !== entry.file);
        root.rebuildPins();
    }

    // Delete a pin *and* the history row it was standing in for. `unpin` alone
    // only drops the copy: `items` was hiding the source row by id, so removing
    // the pin hands it straight back and the entry reappears further along the
    // strip — which reads as a delete that didn't take. Anything already
    // evicted from cliphist just isn't there to match.
    function forget(entry: var): void {
        root.unpin(entry);
        if (entry.srcId)
            root.remove(entry.srcId);
    }

    // wl-copy offers text by default; bytes have to go back out under the type
    // they came in as or the target sees nothing it can take.
    function pinMime(entry: var): string {
        if (!entry.image)
            return "";
        const kind = `${entry.kind}`.toLowerCase();
        if (!kind)
            return "application/octet-stream";
        if (kind === "svg")
            return "image/svg+xml";
        return `image/${kind === "jpg" ? "jpeg" : kind}`;
    }

    function pumpPins(): void {
        if (pinner.running || pinner.current || pinner.queue.length === 0)
            return;
        const job = pinner.queue[0];
        pinner.queue = pinner.queue.slice(1);
        pinner.current = job.rec;
        // A text payload comes back on stdout as well as to disk: the batched
        // decode behind `fullText` may not have landed yet, and pinning a long
        // path before it does would freeze cliphist's elided preview into the
        // pin — the row would read "…" where its filename should be, forever.
        const echo = job.rec.image ? "" : `head -c 400 '${job.rec.file}' | tr '\\n\\t' '  '`;
        // Decoded to a .part and moved into place only once it has bytes in
        // it. The shell creates the redirect target *before* exec'ing
        // cliphist, so a failed decode — an id evicted since the listing, or
        // the store briefly locked by the wl-paste watcher, which is the case
        // this check exists for — used to leave a zero-byte file behind with
        // no record pointing at it, and nothing ever swept the directory.
        pinner.command = ["sh", "-c", `
            mkdir -p '${root.pinDir}' || exit 1
            if cliphist decode ${job.id} > '${job.rec.file}.part' && [ -s '${job.rec.file}.part' ]; then
                mv '${job.rec.file}.part' '${job.rec.file}' || exit 1
                ${echo}
                exit 0
            fi
            rm -f '${job.rec.file}.part'
            exit 1
        `];
        pinner.running = true;
    }

    function storePin(rec: var): void {
        pinStore.items = [rec, ...(pinStore.items ?? [])];
        root.rebuildPins();
    }

    function rebuildPins(): void {
        const byFile = {};
        for (const p of root.pins)
            byFile[p.file] = p;
        // Records never change once written, so a file we've already wrapped
        // keeps its row object — see `pins`.
        root.pins = (pinStore.items ?? []).map(rec => byFile[rec.file] ?? root.pinRow(rec));
    }

    // Shaped like a cliphist row so the delegate never has to ask which store
    // a row came from, plus the file and type that make it independent of one.
    function pinRow(rec: var): var {
        return {
            // Numeric everywhere else, so this can't collide with a real id.
            id: `pin:${rec.file}`,
            pinned: true,
            // The history row this was pinned from — see `items`. Absent on
            // pins written before this was recorded, which then hide nothing.
            srcId: rec.srcId ?? "",
            file: rec.file,
            mime: rec.mime,
            preview: rec.preview,
            image: rec.image,
            kind: rec.kind,
            dims: rec.dims,
            size: rec.size,
            paths: rec.image ? [] : root.parsePaths(rec.preview),
            // The stored text is the whole text; there is nothing to re-read.
            truncated: false
        };
    }

    FileView {
        path: Quickshell.statePath("clipboard-pins.json")
        // Temp-file + rename: a crash mid-write must never replace the pins
        // with a truncated file.
        atomicWrites: true
        onAdapterUpdated: writeAdapter()
        onLoaded: root.rebuildPins()
        onLoadFailed: error => {
            // Only a genuinely missing file gets defaults written over it —
            // any other failure must not let the next write clobber data.
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        adapter: JsonAdapter {
            id: pinStore

            // [{ file, mime, preview, image, kind, dims, size }], newest first.
            property var items: []
        }
    }

    // Failures here land after the picker has closed itself, so they have no
    // surface of their own to report on. Through notify-send like the Asus and
    // battery warnings, rather than the internal server, so it still shows if
    // the shell's own toast stack is what's wedged.
    function notify(summary: string, body: string): void {
        Quickshell.execDetached(["notify-send", "-a", "qshell", "-i", "edit-paste", summary, body]);
    }

    // ── Copying ──

    // Puts a row on the clipboard and, when paste-on-select is on, sends it
    // into `addr` — the window the picker was opened over. Pass an empty
    // address to only load the clipboard.
    function copyEntry(entry: var, addr: string, cls: string): void {
        // Process defers a command set while it is still running and starts it
        // on the old one's exit — so a second request would fire the *old*
        // payload's paste at the new target and then run again. Dropping is
        // right rather than queueing: the picker closes on the first one, so a
        // second is a double-click, not a second intention.
        if (copier.running)
            return;
        copier.addr = addr;
        copier.cls = cls;
        // A pin reads its own payload: after a wipe there is no id left to
        // decode, which is the exact moment you reach for a pin. cliphist
        // takes the id as an argument; feeding it on stdin fails on the
        // trailing newline ("converting id: strconv.Atoi").
        // pipefail on the history path: without it the pipeline's status is
        // wl-copy's, wl-copy forks and returns 0 whatever it read, and a
        // decode that failed (the id evicted since the listing) would still
        // look like a successful copy — which paste-on-select would then send
        // a Ctrl+V after, pasting whatever was on the clipboard before.
        copier.command = ["sh", "-c", entry.pinned ? `wl-copy${entry.mime ? ` --type '${entry.mime}'` : ""} < '${entry.file}'` : `set -o pipefail; cliphist decode ${entry.id} | wl-copy`];
        copier.running = true;
    }

    // Public because the launcher's emoji picker wants exactly this step once
    // its own copy has landed.
    function pasteInto(addr: string, cls: string): void {
        if (!Settings.clipboardPaste)
            return;
        const target = root.windowAddress(addr);
        if (!target)
            return;
        // Terminals have plain Ctrl+V spoken for. Anchored: a window class is
        // an exact string, and an unanchored `st` alternative matches Steam,
        // Postman and libreoffice-startcenter — all of which would then be
        // sent a Ctrl+Shift+V that does nothing, with the clipboard correctly
        // loaded, which looks exactly like the feature being broken.
        const terminals = Settings.clipboardPasteTerminals;
        const mods = terminals && new RegExp(`^(?:${terminals})$`, "i").test(cls) ? "CTRL SHIFT" : "CTRL";
        // Addressed at the window rather than aimed at "whatever is focused":
        // the picker's focus grab is still coming down as this goes out, and a
        // paste that waits for focus to settle is a paste that lands somewhere
        // else when it doesn't. A window that has closed in the meantime logs
        // a hyprland warning and does nothing.
        Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.send_shortcut({ mods = "${mods}", key = "V", window = "address:${target}" })` : `sendshortcut ${mods}, V, address:${target}`);
    }

    // A hyprland toplevel reports a bare hex address while its lastIpcObject
    // reports a 0x-prefixed one, and only the prefixed form resolves. Anything
    // that isn't an address is dropped rather than interpolated into lua.
    function windowAddress(addr: string): string {
        const hex = `${addr}`.replace(/^0x/i, "");
        return /^[0-9a-f]+$/i.test(hex) ? `0x${hex}` : "";
    }

    Process {
        id: copier

        property string addr: ""
        property string cls: ""

        // The paste can only go out once wl-copy owns the selection, and
        // execDetached leaves nothing to wait on — hence a tracked Process.
        // A fixed sleep instead would be a visible stall on a fast machine and
        // still a race on a loaded one.
        onExited: exitCode => {
            if (exitCode === 0) {
                root.pasteInto(copier.addr, copier.cls);
                return;
            }
            // The picker closed on the click, so there is nothing left on
            // screen to put this on. Silence here meant the clipboard still
            // held the *previous* thing and the next Ctrl+V pasted it — the
            // failure looked exactly like a successful copy of the wrong entry.
            root.notify("Couldn't copy that entry", "It is no longer in the clipboard store. History refreshed.");
            root.refresh();
        }
    }

    Process {
        id: pinner

        // One at a time — see pumpPins.
        property var queue: []
        property var current: null

        onExited: exitCode => {
            if (exitCode === 0 && pinner.current) {
                // streamEnded runs before exited, so the payload's own text is
                // already here and beats the preview the row was built from.
                const decoded = pinner.current.image ? "" : payload.text.trim();
                if (decoded)
                    pinner.current.preview = decoded;
                root.storePin(pinner.current);
            } else if (pinner.current) {
                // A pin that fails writes nothing and the card simply stays
                // unpinned — indistinguishable from never having pressed it,
                // on the one action whose whole purpose is that the entry
                // survives what happens to the store.
                root.notify("Couldn't pin that entry", "The clipboard store had nothing left to copy from.");
            }
            pinner.current = null;
            root.pumpPins();
        }

        stdout: StdioCollector {
            id: payload
        }
    }

    Process {
        id: lister

        command: ["cliphist", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    if (!line)
                        continue;
                    const tab = line.indexOf("\t");
                    if (tab < 1)
                        continue;
                    const preview = line.slice(tab + 1);
                    // cliphist previews binaries as "[[ binary data 576 KiB png 2228x609 ]]".
                    // The inner fields are best-effort: older entries and
                    // non-image binaries can lack the format or the dimensions.
                    const img = preview.match(/^\[\[\s*binary data\s+(.*?)\s*\]\]$/);
                    const meta = img ? img[1] : "";
                    const size = meta.match(/(\d+(?:\.\d+)?\s*[KMG]?i?B)/i);
                    const dims = meta.match(/(\d+)\s*x\s*(\d+)/);
                    const kind = meta.match(/\b(png|jpe?g|gif|webp|bmp|svg|tiff?)\b/i);
                    out.push({
                        id: line.slice(0, tab),
                        preview: preview,
                        image: img !== null,
                        meta: meta,
                        kind: kind ? kind[1].toUpperCase() : "",
                        dims: dims ? `${dims[1]}×${dims[2]}` : "",
                        size: size ? size[1].replace(/\s+/, " ") : "",
                        paths: img ? [] : root.parsePaths(preview),
                        // cliphist previews cap at 100 chars, and a path's
                        // filename is exactly what falls off the end — so these
                        // get the full text re-read before being shown.
                        truncated: preview.endsWith("…")
                    });
                }
                root.entries = out;
                root.loaded = true;

                // Batch-decode the truncated text entries search can't see
                // yet (bounded, ids are numeric so the interpolation is safe).
                const need = out.filter(e => e.truncated && !e.image && root.fullText[e.id] === undefined).map(e => e.id).slice(0, 64);
                if (need.length > 0) {
                    decoder.command = ["sh", "-c", `for id in ${need.join(" ")}; do printf '%s\\t' "$id"; cliphist decode "$id" 2>/dev/null | head -c 400 | tr '\\n\\t' '  '; printf '\\n'; done`];
                    decoder.running = true;
                }
            }
        }
    }

    Process {
        id: decoder

        stdout: StdioCollector {
            onStreamFinished: {
                const m = Object.assign({}, root.fullText);
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 1)
                        continue;
                    // A failed decode (db briefly locked by the store watcher)
                    // still emits "id\t" — caching "" would make the entry
                    // permanently unsearchable AND block the retry. Leave it
                    // undefined so search falls back to the preview and the
                    // next listing re-queues it.
                    const payload = line.slice(tab + 1);
                    if (payload.trim())
                        m[line.slice(0, tab)] = payload;
                }
                root.fullText = m;
            }
        }
    }
}
