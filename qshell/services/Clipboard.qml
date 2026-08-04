pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Clipboard history on top of cliphist — the same store the old
// `cliphist list | wofi --show dmenu | cliphist decode | wl-copy` binding used,
// so history carries over and `wl-paste --watch cliphist store` (started in
// hyprland's startup.lua) stays the only writer.
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
        lister.running = false;
        lister.running = true;
    }

    // cliphist takes the id as an argument; feeding it on stdin fails on the
    // trailing newline ("converting id: strconv.Atoi").
    function copy(id: string): void {
        Quickshell.execDetached(["sh", "-c", `cliphist decode ${id} | wl-copy`]);
    }

    // delete reads the full "id<TAB>preview" line, so select it back out of
    // list rather than reconstructing it.
    function remove(id: string): void {
        Quickshell.execDetached(["sh", "-c", `cliphist list | awk -F'\\t' -v id=${id} '$1 == id' | cliphist delete`]);
        entries = entries.filter(e => e.id !== id);
    }

    function wipe(): void {
        Quickshell.execDetached(["cliphist", "wipe"]);
        Quickshell.execDetached(["sh", "-c", `rm -rf ${root.thumbDir}`]);
        entries = [];
    }

    function search(query: string): var {
        const q = query.trim();
        if (!q)
            return root.entries;
        return root.entries.map(e => ({
                    e,
                    // Full text when the preview was cut — search matches what
                    // the row visibly says.
                    score: Apps.scoreText(root.fullText[e.id] ?? e.preview, q)
                })).filter(r => r.score > 0).sort((a, b) => b.score - a.score).slice(0, 64).map(r => r.e);
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
