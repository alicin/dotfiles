pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.services

// Everything the launcher can find. Apps were the only source; a prefix typed
// at the front of the query now swaps the source without leaving the panel —
// which is how the last three daily surfaces that still shelled out to wofi
// (window switcher), or didn't exist at all (calculator, emoji, command
// palette), get to live in one place.
//
// Rows are plain JS objects rather than typed models: the sources have nothing
// in common but a name and a verb, and ScriptModel takes whatever it is given.
//   { kind, name, sub, icon, glyph, char, badge, entry, run, switchTo, confirm }
// `run` is the verb. `switchTo` re-enters the launcher in another mode instead
// of closing it. `confirm` demands a second Enter before `run` fires.
Singleton {
    id: root

    // The `?` row is deliberately last and deliberately in the list: it is
    // both the help mode's own entry and the thing the help button toggles.
    readonly property var modes: [
        {
            key: "",
            glyph: "square_grid_2x2",
            name: "Apps",
            hint: "Installed applications and their jump-list actions"
        },
        {
            key: ">",
            glyph: "command",
            name: "Commands",
            hint: "Theme, capture, power, notifications, session"
        },
        {
            key: "/",
            glyph: "macwindow",
            name: "Windows",
            hint: "Open windows, most recently focused first"
        },
        {
            key: ":",
            glyph: "smiley",
            name: "Emoji",
            hint: "Search by name; Enter copies to the clipboard"
        },
        {
            key: "!",
            glyph: "greaterthan_square",
            name: "Run",
            hint: "Run a command; Shift+Enter runs it in a terminal"
        },
        // Its own mode rather than rows in `>`. There are sixteen themes: as
        // palette entries they were three quarters of everything `>` listed,
        // burying capture, power and the session verbs under a wall of
        // near-identical rows. `#` because a theme is a set of colours and
        // that is what a colour looks like when written down.
        {
            key: "#",
            glyph: "paintbrush",
            name: "Themes",
            hint: "Switch the shell's colour theme; the active one is marked"
        },
        {
            key: "?",
            glyph: "question_circle",
            name: "Help",
            hint: "This list"
        }
    ]

    readonly property var prefixes: root.modes.map(m => m.key).filter(k => k !== "")

    // Asks the launcher to open in a mode, from outside the launcher. The
    // Control Center's theme row is the first caller: it hands the picker off
    // to `#` rather than trying to be one in a 340px panel.
    //
    // A signal on the service both ends already import, rather than the two
    // alternatives — reaching across module boundaries into another window's
    // internals, or shelling out to our own `qs ipc call launcher mode`, which
    // spawns a process to talk to ourselves.
    signal requestMode(string prefix)

    function openMode(prefix: string): void {
        if (root.prefixes.includes(prefix))
            root.requestMode(prefix);
    }

    function modeOf(query: string): string {
        const c = (query + "")[0] ?? "";
        return root.prefixes.includes(c) ? c : "";
    }

    function bodyOf(query: string): string {
        return root.modeOf(query) === "" ? query : (query + "").slice(1);
    }

    function modeInfo(key: string): var {
        return root.modes.find(m => m.key === key) ?? root.modes[0];
    }

    function placeholder(query: string): string {
        switch (root.modeOf(query)) {
        case ">":
            return "Run a shell command…";
        case "/":
            return "Switch to a window…";
        case ":":
            return "Find an emoji…";
        case "!":
            return "Command line…";
        case "#":
            return "Pick a theme…";
        case "?":
            return "";
        default:
            // The prefixes only pay off if they are advertised where someone
            // is already looking. This is that place.
            return "Search apps…    > commands   / windows   : emoji";
        }
    }

    // ── Rows ──
    //
    // ScriptModel diffs by object identity, so rebuilding every row on every
    // keystroke resets the entire model — delegates are destroyed and rebuilt
    // (icons and all) under a stationary cursor. Rows are memoised on a key
    // that encodes everything the row *shows*: when the label changes the key
    // changes and the row is legitimately new.
    property var rowCache: ({})

    function cached(key: string, build: var): var {
        let row = root.rowCache[key];
        if (!row) {
            // Windows close, apps come and go, 1400 emoji get browsed. This
            // is a render optimisation, not a store — drop it wholesale
            // rather than tracking liveness per row.
            if (Object.keys(root.rowCache).length > 4000)
                root.rowCache = {};
            row = build();
            root.rowCache[key] = row;
        }
        return row;
    }

    function results(query: string): var {
        const mode = root.modeOf(query);
        const q = root.bodyOf(query).trim();

        switch (mode) {
        case ">":
            return root.rank(root.commands(), q);
        case "/":
            return root.windows(q);
        case ":":
            return Emoji.search(q).map(e => root.emojiRow(e));
        case "!":
            return root.runRows(q);
        case "#":
            return root.themeRows(q);
        case "?":
            return root.helpRows();
        }

        const rows = Apps.search(q).map(e => root.appRow(e));
        // Jump lists ride along with their app rather than forming a mode of
        // their own — "firefox private" should find the window you meant, and
        // an empty query listing every action of every app is noise.
        if (q)
            rows.push(...root.actions(q));
        const sum = root.calcRow(q);
        if (sum)
            rows.unshift(sum);
        // Last resort, never a competitor: if nothing matched, the thing you
        // typed was probably a command. "No matches" was the old answer.
        if (q && rows.length === 0)
            rows.push(...root.runRows(q));
        return rows;
    }

    // Shared scorer for the row sources that are plain text (commands,
    // actions) — apps, windows and emoji each score against their own fields.
    function rank(rows: var, q: string): var {
        if (!q)
            return rows;
        return rows.map(r => ({
                    r,
                    score: Math.max(Apps.scoreText(r.name, q), Apps.scoreText(r.sub, q) * 0.6)
                })).filter(x => x.score > 0).sort((a, b) => b.score - a.score).map(x => x.r);
    }

    function appRow(entry: var): var {
        return root.cached(`a|${entry.id}`, () => ({
                    kind: "app",
                    name: entry.name,
                    sub: entry.comment || entry.genericName || "",
                    icon: (entry.icon && Quickshell.iconPath(entry.icon, true)) || Quickshell.iconPath("application-x-executable", true) || "",
                    entry: entry,
                    run: () => Apps.launch(entry)
                }));
    }

    // DesktopEntry.actions has been sitting there unread: "New Private
    // Window", "New Incognito Window", "Compose Message" — the second thing
    // anyone wants from a browser or a mail client.
    function actions(q: string): var {
        // Two characters minimum: "n" matches a "New Window" on half the
        // applications installed, and those rows would be the entire list.
        if (q.length < 2)
            return [];
        const scored = [];
        for (const entry of Apps.all) {
            const acts = entry.actions ?? [];
            if (acts.length === 0)
                continue;
            const byApp = Apps.scoreText(entry.name, q);
            for (const a of acts) {
                // Found by the app's name OR by the action's own words —
                // "private window" is how you look for it at least as often
                // as "chrome" is.
                const score = Math.max(byApp, Apps.scoreText(`${entry.name} ${a.name}`, q), Apps.scoreText(a.name, q));
                if (score <= 0)
                    continue;
                scored.push({
                    score,
                    row: root.cached(`x|${entry.id}|${a.name}`, () => ({
                            kind: "action",
                            name: `${entry.name}  ▸  ${a.name}`,
                            sub: entry.comment || entry.genericName || "",
                            icon: (entry.icon && Quickshell.iconPath(entry.icon, true)) || "",
                            badge: "Action",
                            run: () => {
                                // Frecency is per app, and running one of its
                                // actions is still using the app.
                                Apps.record(entry);
                                a.execute();
                            }
                        }))
                });
            }
        }
        // Capped, and they sit *under* the app matches rather than instead of
        // them: a jump list is a shortcut, not a competitor to the app.
        return scored.sort((a, b) => b.score - a.score).slice(0, 8).map(x => x.row);
    }

    function windows(q: string): var {
        const rows = Windows.list.map(t => {
            const ws = t.workspace;
            const cls = ((t.lastIpcObject?.class || t.wayland?.appId) ?? "") + "";
            const title = t.title || t.lastIpcObject?.title || cls || "Untitled";
            // "special" with no colon IS the unnamed scratchpad — the named
            // ones are "special:void" and friends. Stripping the prefix leaves
            // the unnamed one labelled "special", which is a name it does not
            // have anywhere else in this shell.
            const wsName = `${ws?.name ?? ""}`;
            const where = !ws ? "" : ws.id < 0 ? (wsName === "special" ? "scratchpad" : wsName.replace(/^special:/, "") || "scratchpad") : `Workspace ${ws.id}`;
            const addr = Windows.keyOf(t);
            return root.cached(`w|${addr}|${title}|${where}`, () => ({
                        kind: "window",
                        name: title,
                        sub: [cls, where].filter(s => s).join("  ·  "),
                        icon: Apps.toplevelIcon(t),
                        // The address, not the object: Hyprland reuses
                        // addresses and Quickshell deletes a toplevel outright
                        // when it closes, so a cached row that captured one
                        // would activate into nothing.
                        run: () => Windows.focusAddress(addr),
                        // Scoring fodder: the class is how you think of a
                        // window ("kitty") even when its title says something
                        // else entirely.
                        match: `${title} ${cls}`
                    }));
        });
        if (!q)
            return rows;
        return rows.map(r => ({
                    r,
                    score: Apps.scoreText(r.match, q)
                })).filter(x => x.score > 0).sort((a, b) => b.score - a.score).map(x => x.r);
    }

    function emojiRow(e: var): var {
        return root.cached(`e|${e.c}`, () => ({
                    kind: "emoji",
                    name: e.n,
                    sub: e.k ?? "",
                    char: e.c,
                    badge: "Copy",
                    run: () => Emoji.pick(e.c)
                }));
    }

    function runRows(cmd: string): var {
        const c = cmd.trim();
        if (!c)
            return [];
        return [
            {
                kind: "run",
                name: c,
                sub: "Run command",
                glyph: "greaterthan_square",
                badge: "⇧⏎ terminal",
                run: () => Quickshell.execDetached(["sh", "-c", c]),
                // Shift+Enter keeps the output: a command run detached that
                // prints an error prints it into nothing. The status is read
                // into `rc` on the very next line — one intervening `echo` and
                // `$?` is that echo's, which is always 0 and makes the whole
                // point of this variant a lie.
                alt: () => Quickshell.execDetached([Settings.terminal, "sh", "-c", `${c}
rc=$?
echo
echo "[exit $rc] — press enter"
read _`])
            }
        ];
    }

    // The theme picker. Rows carry `swatch` — the theme's own key — and the
    // delegate paints that theme's actual surface and accent, because sixteen
    // names in a list tell you nothing about which one you want and the whole
    // subject here is what things look like.
    //
    // Listed in Theme.qml's own order, which groups families light-to-dark,
    // rather than sorted or frecency-ranked: picking a theme is browsing, and a
    // list that reorders itself between visits can't be learned. The active one
    // stays in place and is badged instead of being hoisted.
    function themeRows(q: string): var {
        const rows = Theme.available.map(name => {
            const t = Theme.themes[name];
            const on = name === Settings.theme;
            // `on` is in the cache key: the badge moves when the theme does,
            // and a row memoised without it would keep the stale "Active".
            return root.cached(`t|${name}|${on}`, () => ({
                    kind: "theme",
                    name: Theme.label(name),
                    // The raw key, so `#rose` and `#mocha` both find things —
                    // and so the value settings.json wants is on screen.
                    sub: `${t.light ? "Light" : "Dark"}  ·  ${name}`,
                    swatch: name,
                    badge: on ? "Active" : "",
                    // The panel is the preview: it restyles the moment the
                    // setting lands, so the picker stays up to be compared
                    // against rather than closing on every try.
                    keepOpen: true,
                    run: () => Settings.setTheme(name)
                }));
        });
        return root.rank(rows, q);
    }

    function helpRows(): var {
        const rows = root.modes.filter(m => m.key !== "?").map(m => root.cached(`h|${m.key}`, () => ({
                    kind: "help",
                    name: m.key === "" ? "Apps  (no prefix)" : `${m.key}   ${m.name}`,
                    sub: m.hint,
                    glyph: m.glyph,
                    switchTo: m.key
                })));
        // Keys, as inert rows. The prefixes above are discoverable by typing;
        // these are not discoverable at all without being written down.
        const key = (name, sub) => root.cached(`k|${name}`, () => ({
                kind: "hint",
                name,
                sub,
                glyph: "keyboard"
            }));
        rows.push(key("↑ ↓ · PgUp PgDn", "Move the selection; it wraps at both ends"));
        rows.push(key("⏎", "Launch, focus, copy or run the selected row"));
        rows.push(key("⇧⏎", "The row's alternate verb, where it has one"));
        rows.push(key("Esc", "Close — or drop back out of a prefix mode first"));
        rows.push(key("Type a number", "Anything that parses as arithmetic answers itself"));
        return rows;
    }

    // ── Calculator ──
    //
    // A recursive-descent parser rather than eval(): the query is arbitrary
    // typed text, and handing that to a JS evaluator inside the shell process
    // is a class of bug this shell shouldn't have.

    function calcRow(q: string): var {
        const r = root.calc(q);
        if (r === null)
            return null;
        return {
            kind: "calc",
            name: r,
            sub: q,
            glyph: "equal",
            badge: "Copy",
            // `--`, because wl-copy takes its text as argv and getopt eats a
            // leading dash: `1-5` answers `-4`, and `wl-copy -4` is an
            // "invalid option" that never reaches the clipboard.
            run: () => Quickshell.execDetached(["wl-copy", "--", r])
        };
    }

    readonly property var constants: ({
            pi: Math.PI,
            e: Math.E,
            tau: Math.PI * 2
        })

    readonly property var funcs: ({
            sqrt: Math.sqrt,
            cbrt: Math.cbrt,
            abs: Math.abs,
            round: Math.round,
            floor: Math.floor,
            ceil: Math.ceil,
            ln: Math.log,
            log: x => Math.log10(x),
            log2: Math.log2,
            exp: Math.exp,
            sin: Math.sin,
            cos: Math.cos,
            tan: Math.tan,
            asin: Math.asin,
            acos: Math.acos,
            atan: Math.atan,
            sign: Math.sign
        })

    // "" when the text isn't arithmetic at all — the caller shows no row.
    function calc(src: string): var {
        const s = (src + "").trim();
        if (!s || s.length > 200)
            return null;

        const tokens = [];
        let i = 0;
        while (i < s.length) {
            const c = s[i];
            if (c === " " || c === "_" || c === ",") {
                i++;
                continue;
            }
            if (c >= "0" && c <= "9" || c === ".") {
                const m = /^\d*\.?\d+(?:[eE][-+]?\d+)?/.exec(s.slice(i));
                if (!m)
                    return null;
                tokens.push({
                    t: "num",
                    v: parseFloat(m[0])
                });
                i += m[0].length;
                continue;
            }
            if (/[a-z]/i.test(c)) {
                const m = /^[a-z]\w*/i.exec(s.slice(i));
                tokens.push({
                    t: "name",
                    v: m[0].toLowerCase()
                });
                i += m[0].length;
                continue;
            }
            if ("+-*/%^()".includes(c)) {
                tokens.push({
                    t: c
                });
                i++;
                continue;
            }
            // × and ÷ arrive from other applications' text often enough to
            // be worth accepting.
            if (c === "×") {
                tokens.push({
                    t: "*"
                });
                i++;
                continue;
            }
            if (c === "÷") {
                tokens.push({
                    t: "/"
                });
                i++;
                continue;
            }
            return null;
        }

        // A bare number is not a calculation, and neither is a bare word —
        // without this every query with a digit in it grows a redundant row.
        if (!tokens.some(t => "+-*/%^".includes(t.t) || (t.t === "name" && root.funcs[t.v])))
            return null;

        let p = 0;
        const peek = () => tokens[p];
        const eat = t => {
            if (tokens[p]?.t === t) {
                p++;
                return true;
            }
            return false;
        };

        // Function *declarations*, not const arrows: the grammar is mutually
        // recursive (unary → power → unary, atom → expr → atom) and only
        // hoisting lets every rule name the ones below it.
        function atom() {
            const tok = peek();
            if (!tok)
                return NaN;
            if (tok.t === "num") {
                p++;
                return tok.v;
            }
            if (tok.t === "name") {
                p++;
                if (root.constants[tok.v] !== undefined)
                    return root.constants[tok.v];
                const fn = root.funcs[tok.v];
                if (!fn || !eat("("))
                    return NaN;
                const arg = expr();
                if (!eat(")"))
                    return NaN;
                return fn(arg);
            }
            if (eat("(")) {
                const v = expr();
                if (!eat(")"))
                    return NaN;
                return v;
            }
            return NaN;
        }

        function unary() {
            if (eat("-"))
                return -unary();
            if (eat("+"))
                return unary();
            return power();
        }

        // Right-associative, so 2^3^2 is 512 the way it is on paper.
        function power() {
            const base = atom();
            if (eat("^"))
                return Math.pow(base, unary());
            return base;
        }

        function term() {
            let v = unary();
            for (;;) {
                if (eat("*"))
                    v *= unary();
                else if (eat("/"))
                    v /= unary();
                else if (eat("%"))
                    v %= unary();
                else
                    return v;
            }
        }

        function expr() {
            let v = term();
            for (;;) {
                if (eat("+"))
                    v += term();
                else if (eat("-"))
                    v -= term();
                else
                    return v;
            }
        }

        const value = expr();
        // Trailing junk means the text was something else that happened to
        // start like a sum ("2x4 fence") — no row rather than a wrong one.
        if (p !== tokens.length || typeof value !== "number" || !isFinite(value))
            return null;
        return root.format(value);
    }

    function format(v: real): string {
        // Every integer a double can hold exactly gets printed in full: the
        // old 1e12 cutoff turned 2^40 into "1.099512e+12" and dropped the +1
        // from 1e12+1 — a calculator that rounds the answer it was asked for
        // is worse than no calculator.
        if (Number.isInteger(v) && Math.abs(v) <= Number.MAX_SAFE_INTEGER)
            return `${v}`;
        const a = Math.abs(v);
        if (a !== 0 && (a >= 1e15 || a < 1e-6))
            return v.toExponential(6).replace(/\.?0+e/, "e");
        // Float noise (0.1+0.2) is not an answer anyone asked for.
        return `${Math.round(v * 1e9) / 1e9}`;
    }

    // ── Command palette ──
    //
    // Everything here already had a service behind it and no way to reach it
    // from the keyboard. Rows are rebuilt per keystroke, which is what keeps
    // the labels ("Do Not Disturb: on") honest.

    function commands(): var {
        const out = [];
        // Keyed on what the row says, so a label that tracks live state
        // ("Do Not Disturb: on") becomes a new row exactly when it changes.
        // `switchTo` is left *undefined* rather than "" for ordinary rows:
        // ResultItem treats a present-but-empty switchTo as a real verb (the
        // help row back to app search carries one), so defaulting it would
        // make every command row look launchable even with no run.
        const add = (name, sub, glyph, run, confirm, switchTo) => out.push(root.cached(`c|${name}|${sub}`, () => {
                const row = {
                    kind: "command",
                    name,
                    sub,
                    glyph,
                    run,
                    confirm: confirm === true
                };
                if (switchTo !== undefined)
                    row.switchTo = switchTo;
                return row;
            }));

        add("Screenshot region", "Drag out an area", "camera", () => Capture.shoot("area"));
        add("Screenshot window", "The focused window", "camera", () => Capture.shoot("window"));
        add("Screenshot screen", "After a short countdown", "camera", () => Capture.shoot("full"));
        if (Capture.recording || Capture.paused) {
            // No elapsed time in the subtitle: it is part of the row's cache
            // key, so it would mint a new row object every second — churn in
            // a list someone is arrowing through, to say something the bar's
            // recording chip is already saying.
            add("Stop recording", Capture.paused ? "Paused" : "", "stop_fill", () => Capture.toggleRecording());
            add(Capture.paused ? "Resume recording" : "Pause recording", "", "playpause_fill", () => Capture.togglePause());
        } else {
            add("Record region", "Drag out an area", "videocam", () => Capture.toggleRecording());
            add("Record screen", "The whole screen", "videocam", () => Capture.recordFull());
        }

        add(`Do Not Disturb: ${Notifs.dnd ? "on" : "off"}`, Notifs.dnd ? "Turn notifications back on" : "Silence notifications", Notifs.dnd ? "bell_slash_fill" : "bell_slash", () => Notifs.toggleDnd());
        if (Notifs.count > 0)
            add("Clear notifications", `${Notifs.count} in history`, "trash", () => Notifs.clearAll());
        add(`Keep awake: ${Idle.inhibited ? "on" : "off"}`, Idle.inhibited ? "Let the screen sleep again" : "Hold off dimming, locking and sleep", "eye", () => Idle.toggle());
        if (NightLight.available)
            add(`Night light: ${NightLight.enabled ? "on" : "off"}`, `${NightLight.temperature}K`, "moon", () => NightLight.toggle());
        add(`Wi-Fi: ${Net.wifiEnabled ? "on" : "off"}`, Net.ssid, "wifi", () => Net.toggleWifi());

        for (const p of Power.all) {
            const label = Power.label(p);
            if (p !== Power.profile)
                add(`Power profile: ${label}`, "", Power.glyph(p), () => Power.set(p));
        }

        // One row into `#`, not sixteen rows here. As palette entries the
        // themes were three quarters of everything `>` listed and buried
        // capture, power and the session verbs under a wall of near-identical
        // lines — and none of them showed a single colour.
        add(`Theme: ${Theme.label(Settings.theme)}`, "Browse all themes", "paintbrush", null, false, "#");

        add("Lock screen", "", "lock_fill", () => Quickshell.execDetached(["loginctl", "lock-session"]));
        add("Suspend", "", "moon_fill", () => Quickshell.execDetached(["systemctl", "suspend"]));
        // The destructive three ask twice. A palette is a text field that
        // takes Enter, and "reb" + Enter is one slip away from being typed
        // into the wrong window.
        add("Reboot", "Confirms first", "arrow_2_circlepath", () => Quickshell.execDetached(["systemctl", "reboot"]), true);
        add("Power off", "Confirms first", "power", () => Quickshell.execDetached(["systemctl", "poweroff"]), true);
        add("Log out", "Confirms first", "square_arrow_right", () => Hyprland.dispatch(Hyprland.usingLua ? "hl.dsp.exit()" : "exit"), true);
        add("Reload shell", "Re-read the qshell config", "arrow_2_circlepath", () => Quickshell.reload(false));

        return out;
    }
}
