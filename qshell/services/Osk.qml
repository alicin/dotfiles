pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config

// On-screen keyboard: when it is up, what it types with, and the layouts.
// The panel that draws it is modules/osk/OskPanel.qml.
//
// ── Why wtype ──
// Keys go out through `wtype`, which speaks zwp_virtual_keyboard_v1 — a
// Wayland client protocol, so the keystroke enters at the *compositor*. The
// obvious alternative, ydotool, writes to /dev/uinput, which puts the
// keystroke at the very bottom of the input stack: below libinput, and
// therefore below Toshy (xwaykeyz), which remaps this machine's keyboard into
// a macOS layout. An OSK on that path types `a`, Toshy sees a physical `a`
// from a new device, rewrites it, and what lands in the app is whatever the
// remap says. wtype's output is never seen by Toshy at all.
//
// One consequence to remember: "the modifiers get released automatically once
// the program terminates" (wtype(1)). A chord therefore has to be one
// invocation — press, key, release, all in a single argv — which is why
// send() builds the whole thing instead of latching modifiers in the
// compositor and leaving them there.
Singleton {
    id: root

    // ── Text-input focus ─────────────────────────────────────────────────────
    // Fed by bin/osk-focus-watch, which binds as the seat's zwp_input_method_v2
    // and reports what the compositor relays from applications' text-input. See
    // that file for why it cannot be done from in here.
    property bool focusAvailable: false
    property bool textFocus: false
    // zwp_text_input_v3's content_purpose ("terminal", "password", "digits", …).
    // Not acted on yet; it is what a numeric layout for a PIN field would key
    // off, and it costs nothing to carry now that it arrives anyway.
    property string purpose: "normal"

    // The shell's own panels do not announce text input: they are Qt layer
    // surfaces, and Qt does not drive zwp_text_input_v3 from one — verified by
    // watching the protocol while the launcher's field had focus, and getting
    // nothing. Without this the one place a tablet most needs a keyboard, the
    // launcher, would be the one place that never raised it. popoutTextFocus
    // is the same reasoning extended to the Control Center's fields and the
    // Wi-Fi password — which additionally *lose* the app's text-input focus
    // when the popout's grab takes over, so without their own flag, opening
    // settings actively lowered the keyboard you were about to need.
    readonly property bool shellFieldFocused: Osd.launcherOpen || Osd.clipboardOpen || Osd.popoutTextFocus

    readonly property bool typing: root.textFocus || root.shellFieldFocused

    // ── Visibility ───────────────────────────────────────────────────────────
    // Settings.osk is the policy. "on" pins it up, "off" kills it, and "auto"
    // means what it means on every tablet: up when there is somewhere to type
    // and no keyboard to type on.
    //
    // Both halves matter. Gating on the keyboard alone (the original) left it
    // up for the entire undocked session, permanently eating a third of a
    // 960px-tall screen. Gating on focus alone would raise a keyboard on a
    // docked desktop every time you clicked an address bar — which is exactly
    // what got squeekboard removed from this profile.
    //
    // `focusAvailable` is the fallback hinge: if the watcher is not running, or
    // another input method owns the seat, focus is simply unknown and auto
    // falls back to the old always-up-while-undocked behaviour. A keyboard that
    // is up too often is a nuisance; one that never appears is a machine you
    // cannot type on.
    readonly property bool wanted: {
        if (Settings.osk === "on")
            return true;
        if (Settings.osk !== "auto" || !Tablet.tablet)
            return false;
        return root.focusAvailable ? root.typing : true;
    }

    // A manual show/hide that outranks `wanted` until the hardware changes its
    // mind. null = no override. Dismissing the keyboard has to survive the next
    // keystroke, and forcing it up has to survive a docked keyboard, so this
    // cannot be a plain bool defaulting either way.
    property var manual: null

    readonly property bool active: Settings.osk !== "off" && (root.manual === null ? root.wanted : root.manual)

    // Any change in what the shell *would* have done makes the override stale:
    // it was the answer to a question that is no longer the one being asked.
    // Docking, undocking, and now leaving a text field all clear it — so
    // dismissing the keyboard silences it for the field you are in, and tapping
    // into the next one brings it back, which is what dismissing a keyboard
    // means everywhere else.
    onWantedChanged: root.manual = null

    function toggle(): void {
        root.manual = !root.active;
    }

    function show(): void {
        root.manual = true;
    }

    function dismiss(): void {
        root.manual = false;
    }

    // ── Reserved space ───────────────────────────────────────────────────────
    // Written by the panel once it knows its screen. The layer surface's
    // exclusive zone shrinks *tiled* windows for free; floating ones are left
    // where they are and get cut off by the keyboard, so those are moved out of
    // the way by bin/osk-float-rescue. See the header there.
    property int reservedPx: 0
    property string reservedScreen: ""

    // The keyboard's own window, for panels that hold a HyprlandFocusGrab.
    // Every grab in this shell closes its panel when the grab clears, and a
    // tap anywhere outside the grab's window list clears it — so a grab that
    // doesn't whitelist the keyboard dies on the first key: open the launcher,
    // tap `g`, launcher closes. The panels can't import the module that owns
    // the window (modules must not depend on each other), so it parks here.
    property var panelWindow: null

    readonly property string binDir: `${Quickshell.env("HOME")}/labs/dotfiles/bin`

    // Debounced, because the three properties settle at slightly different
    // times when the keyboard appears (active → screen → height) and each
    // intermediate combination would be its own pass over every floating
    // window. One pass, once it stops moving.
    onActiveChanged: rescue.restart()
    onReservedPxChanged: rescue.restart()
    onReservedScreenChanged: rescue.restart()

    // The helper reported that another input method (fcitx5, ibus) owns the
    // seat. Terminal until the user asks again: respawning into that every
    // three seconds is a loop losing the same race forever. Cleared when the
    // osk setting is touched, which is the "try again" gesture.
    property bool imGaveUp: false

    // Only while the keyboard is not switched off: this holds the seat's one
    // input-method slot for as long as it runs, so turning the OSK off hands
    // that slot back rather than sitting on it.
    //
    // `running` is driven imperatively via syncFocusWatch(), never bound: the
    // restart path has to assign it, and a QML script assignment silently
    // *replaces* a binding — after the first crash-restart, a binding here
    // would be gone and flipping the setting to "off" would no longer stop
    // the process.
    Process {
        id: focusWatch

        command: [`${root.binDir}/osk-focus-watch`]

        // A dead watcher means focus is UNKNOWN. Leaving the last-seen values
        // in place kept `wanted` trusting a stale textFocus for the whole
        // respawn window (or forever, in a crash loop) — the documented
        // "focus unknown → always-up-while-undocked" fallback never engaged.
        onExited: {
            root.focusAvailable = false;
            root.textFocus = false;
            focusWatchRestart.start();
        }

        stdout: SplitParser {
            onRead: line => {
                let state;
                try {
                    state = JSON.parse(line);
                } catch (e) {
                    return;
                }
                root.focusAvailable = state.available === true;
                // Latch only on the helper's genuinely-terminal give-ups
                // (another IM owns the seat, no protocol, no bindings) — it
                // also emits available:false for hiccups it retries itself,
                // and latching on those silently disarmed the QML-side
                // supervision after one transient error. On a real give-up,
                // sync immediately so the seat's one input-method slot is
                // released now, not at the next unrelated exit.
                if (state.available === false && state.terminal === true) {
                    root.imGaveUp = true;
                    root.syncFocusWatch();
                }
                if (typeof state.focus === "boolean")
                    root.textFocus = state.focus;
                if (typeof state.purpose === "string")
                    root.purpose = state.purpose;
            }
        }
    }

    function syncFocusWatch(): void {
        // Touchscreen-gated: the watcher binds the seat's ONE input-method
        // slot (fcitx5/ibus cannot while it runs), and a machine that cannot
        // tap an OSK has no business holding it. `osk: "on"` still runs it —
        // a pinned keyboard driven by a mouse is a legitimate accessibility
        // setup, and pinning it is explicit.
        const want = Settings.osk !== "off" && !root.imGaveUp
            && (Tablet.hasTouchscreen || Settings.osk === "on");
        if (focusWatch.running !== want)
            focusWatch.running = want;
        if (!want)
            root.focusAvailable = false;
    }

    Component.onCompleted: root.syncFocusWatch()

    Connections {
        target: Settings

        function onOskChanged(): void {
            root.imGaveUp = false;
            root.syncFocusWatch();
        }
    }

    Connections {
        target: Tablet

        // Arrives async from the sensor helper, so the gate above has to be
        // re-evaluated when it lands (and if a USB touchscreen is ever
        // plugged in mid-session, this is what turns the watcher on).
        function onHasTouchscreenChanged(): void {
            root.syncFocusWatch();
        }
    }

    Timer {
        id: focusWatchRestart

        interval: 3000
        onTriggered: root.syncFocusWatch()
    }

    // A float that OPENS while the keyboard is already up gets rescued too.
    // The three property hooks above only fire on OSK transitions, so without
    // this a dialog spawned mid-typing sat under the keyboard — the exact
    // window (it's usually a dialog, and its buttons are at the bottom) the
    // rescue exists for.
    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (!root.active)
                return;
            // movewindow: a float dragged onto this workspace from elsewhere
            // arrives un-rescued; workspace: belt-and-braces for anything the
            // monitor-wide sweep missed while a workspace was inactive.
            switch (event.name) {
            case "openwindow":
            case "changefloatingmode":
            case "movewindow":
            case "workspace":
                rescue.restart();
            }
        }
    }

    Timer {
        id: rescue

        interval: 90
        onTriggered: {
            if (root.active && root.reservedPx > 0 && root.reservedScreen !== "")
                Quickshell.execDetached(["sh", "-c", `'${root.binDir}/osk-float-rescue' reserve "$1" "$2"`, "qshell-osk", root.reservedScreen, String(root.reservedPx)]);
            else
                Quickshell.execDetached(["sh", "-c", `'${root.binDir}/osk-float-rescue' restore`, "qshell-osk"]);
        }
    }

    // ── Modifier state ───────────────────────────────────────────────────────
    // One-shot by default: tap Shift, tap a letter, get one capital. A second
    // tap locks it, which is the only way to hold Shift through a run of
    // capitals, or to build Ctrl+Shift+V, with one finger.
    property bool shift: false
    property bool shiftLock: false
    property bool ctrl: false
    property bool ctrlLock: false
    property bool alt: false
    property bool altLock: false
    property bool logo: false
    property bool logoLock: false

    // 0 = letters, 1 = symbols.
    property int layer: 0

    readonly property bool upper: root.shift || root.shiftLock

    // tap → armed for one key, tap again → locked, tap again → off.
    function toggleMod(name: string): void {
        if (root[name + "Lock"]) {
            root[name] = false;
            root[name + "Lock"] = false;
        } else if (root[name]) {
            root[name + "Lock"] = true;
        } else {
            root[name] = true;
        }
    }

    function clearOneShots(): void {
        if (!root.shiftLock)
            root.shift = false;
        if (!root.ctrlLock)
            root.ctrl = false;
        if (!root.altLock)
            root.alt = false;
        if (!root.logoLock)
            root.logo = false;
    }

    // ── Layout data ──────────────────────────────────────────────────────────
    // A row is a list of keys, and a key is either:
    //
    //   a string   the character it types. Shift is resolved through the US
    //              map below, so "a" → "A" and "/" → "?" with no per-key data.
    //   an object  everything else:
    //                k  an X keysym to press instead of typing text ("Return")
    //                a  an action handled in here rather than sent ("shift")
    //                t  literal text, when it isn't expressible as a bare
    //                   string (the space bar)
    //                w  width relative to a plain key (default 1)
    //                g  a Framework7 glyph to draw instead of the label
    //                l  an explicit label ("" draws nothing)
    //                r  repeats while held
    //
    // Rows are normalised to the panel width by total weight, so a row of ten
    // 1-wide keys and a row of nine plus a 1.75-wide Return both fill it —
    // which is why the home row comes out slightly wider, exactly as it does
    // on a real keyboard.
    function spec(key: var): var {
        return typeof key === "string" ? ({
                t: key
            }) : key;
    }

    // The real US layout's shifted forms, rather than per-key data. Letters
    // need no entry — they upper-case — and getting this from one table is
    // what lets a row be written as a list of characters.
    readonly property var shiftMap: ({
            "1": "!",
            "2": "@",
            "3": "#",
            "4": "$",
            "5": "%",
            "6": "^",
            "7": "&",
            "8": "*",
            "9": "(",
            "0": ")",
            "-": "_",
            "=": "+",
            "[": "{",
            "]": "}",
            "\\": "|",
            ";": ":",
            "'": "\"",
            ",": "<",
            ".": ">",
            "/": "?",
            "`": "~"
        })

    // wtype resolves named keys through libxkbcommon, so `-k` wants an X
    // keysym name. Letters and digits are their own keysym; punctuation is
    // not, and this is the table for the ones these layouts can produce. Only
    // needed on the modifier path (Ctrl+/); plain typing goes out as text,
    // which wtype maps itself and which is the only path that handles the
    // characters outside ASCII at all.
    readonly property var keysyms: ({
            " ": "space",
            // The symbols layer's non-ASCII keys: `-k` with the raw character
            // makes wtype exit "Unknown key" — a latched Ctrl + any of these
            // silently did nothing (plain typing is fine, that path is text).
            "€": "EuroSign",
            "£": "sterling",
            "°": "degree",
            "…": "ellipsis",
            "!": "exclam",
            "\"": "quotedbl",
            "#": "numbersign",
            "$": "dollar",
            "%": "percent",
            "&": "ampersand",
            "'": "apostrophe",
            "(": "parenleft",
            ")": "parenright",
            "*": "asterisk",
            "+": "plus",
            ",": "comma",
            "-": "minus",
            ".": "period",
            "/": "slash",
            ":": "colon",
            ";": "semicolon",
            "<": "less",
            "=": "equal",
            ">": "greater",
            "?": "question",
            "@": "at",
            "[": "bracketleft",
            "\\": "backslash",
            "]": "bracketright",
            "^": "asciicircum",
            "_": "underscore",
            "`": "grave",
            "{": "braceleft",
            "|": "bar",
            "}": "braceright",
            "~": "asciitilde"
        })

    // What a key produces right now, given the shift state.
    function textOf(key: var): string {
        const s = root.spec(key);
        if (s.t === undefined)
            return "";
        if (!root.upper)
            return s.t;
        return root.shiftMap[s.t] ?? s.t.toUpperCase();
    }

    // What a key shows right now. Glyph keys draw a glyph instead and never
    // reach this; `l: ""` is how the space bar asks for a blank cap.
    function labelOf(key: var): string {
        const s = root.spec(key);
        if (s.l !== undefined)
            return s.l;
        if (s.t !== undefined)
            return root.textOf(key);
        return s.k ?? "";
    }

    // ── Special keys ─────────────────────────────────────────────────────────
    // Defined once and shared between the layers, so the rows below stay
    // readable as rows.
    readonly property var kBackspace: ({
            k: "BackSpace",
            g: "delete_left",
            w: 1.5,
            r: true
        })
    readonly property var kReturn: ({
            k: "Return",
            g: "arrow_turn_down_left",
            w: 1.75
        })
    readonly property var kShift: ({
            a: "shift",
            g: "shift",
            w: 1.5
        })
    readonly property var kSpace: ({
            t: " ",
            l: "",
            w: 6
        })
    readonly property var kToSymbols: ({
            a: "layer",
            g: "textformat_123",
            w: 1.6
        })
    readonly property var kToLetters: ({
            a: "layer",
            g: "textformat_abc",
            w: 1.6
        })

    // Above every layer: the keys a touchscreen has no other way to reach.
    // Escape and Tab because nothing else produces them, the arrows because
    // dragging a text cursor with a fingertip is hopeless, and the modifiers
    // up here rather than on the bottom row so the chord you are building stays
    // visible while you go looking for the letter.
    // Named in words rather than in glyphs, unlike the rest of the shell.
    // Framework7's `escape` is a hooked arrow that reads as "undo" at 20px, and
    // ⌥/⌘ are the *macOS* names for these keys — which on this machine is
    // actively misleading: Toshy remaps the physical keyboard into a macOS
    // layout, but wtype injects at the compositor and bypasses it, so what a
    // window receives from these three is plain Ctrl, Alt and Super. Labelling
    // them ⌥ and ⌘ would name the layout this keyboard is the one thing that
    // does not go through.
    readonly property var rowUtility: [
        {
            k: "Escape",
            l: "esc",
            w: 1.2
        },
        {
            k: "Tab",
            l: "tab",
            w: 1.2
        },
        {
            a: "ctrl",
            l: "ctrl",
            w: 1.2
        },
        {
            a: "alt",
            l: "alt",
            w: 1.2
        },
        {
            a: "logo",
            l: "super",
            w: 1.2
        },
        {
            k: "Left",
            g: "arrow_left",
            r: true
        },
        {
            k: "Up",
            g: "arrow_up",
            r: true
        },
        {
            k: "Down",
            g: "arrow_down",
            r: true
        },
        {
            k: "Right",
            g: "arrow_right",
            r: true
        },
        {
            a: "hide",
            g: "keyboard_chevron_compact_down",
            w: 1.4
        }
    ]

    // ── The layers ───────────────────────────────────────────────────────────
    // Letters, then symbols. The symbol layer is chosen for a terminal and an
    // editor, which is what this machine is for: brackets of every kind, the
    // shell metacharacters, the arithmetic, and the navigation keys. It is not
    // an emoji drawer — that already exists, in the launcher's `:` mode.
    readonly property var layers: [
        [
            ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", root.kBackspace],
            ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
            ["a", "s", "d", "f", "g", "h", "j", "k", "l", root.kReturn],
            [root.kShift, "z", "x", "c", "v", "b", "n", "m", ",", ".", root.kShift],
            [root.kToSymbols, "/", root.kSpace, "-", "'"]
        ],
        [
            ["!", "@", "#", "$", "%", "^", "&", "*", "(", ")", root.kBackspace],
            ["`", "~", "[", "]", "{", "}", "<", ">", "|", "\\"],
            ["=", "+", "-", "_", ":", ";", "\"", "'", "?", root.kReturn],
            [
                {
                    k: "Home",
                    l: "home",
                    w: 1.5
                },
                {
                    k: "End",
                    l: "end"
                },
                {
                    k: "Prior",
                    l: "pgup"
                },
                {
                    k: "Next",
                    l: "pgdn"
                },
                {
                    k: "Delete",
                    l: "del",
                    r: true
                },
                "€",
                "£",
                "°",
                "…",
                {
                    k: "Insert",
                    l: "ins",
                    w: 1.5
                }
            ],
            [root.kToLetters, "/", root.kSpace, ",", "."]
        ]
    ]

    readonly property var rows: root.layers[root.layer] ?? root.layers[0]

    // ── Sending ──────────────────────────────────────────────────────────────
    // Split from send() so the command line is inspectable without a keystroke
    // leaving the shell: this is the part with all the decisions in it (which
    // of three encodings a key takes, whether Shift is a modifier or already
    // baked into the character), and the part worth testing. Returns [] for an
    // action key, which sends nothing.
    function argvFor(key: var): var {
        const s = root.spec(key);
        if (s.a !== undefined)
            return [];

        const mods = [];
        if (root.ctrl)
            mods.push("ctrl");
        if (root.alt)
            mods.push("alt");
        if (root.logo)
            mods.push("logo");

        const named = s.k;
        const text = root.textOf(key);

        // Shift only has to be *held* when something else is held with it, or
        // when the key is a named one (Shift+Tab). A shifted letter on its own
        // goes out as the capital, which needs no modifier at all — and must
        // not get one, or the app sees Shift+A and prints nothing.
        if (root.upper && (named !== undefined || mods.length > 0))
            mods.push("shift");

        const argv = ["wtype"];
        for (const m of mods)
            argv.push("-M", m);

        if (named !== undefined) {
            argv.push("-k", named);
        } else if (mods.length > 0) {
            // The *unshifted* character, deliberately. Shift is already in
            // `mods` at this point, and asking libxkbcommon for the keysym `V`
            // means "the thing shift+v produces" — so Ctrl+Shift+V went out as
            // shift held around a keysym that itself implies shift. Apps that
            // resolve the chord by keycode saw the right thing by luck; the
            // honest encoding is to hold shift and press plain `v`.
            const base = s.t;
            argv.push("-k", root.keysyms[base] ?? base);
        } else {
            // `--` ends the options, so the hyphen key types a hyphen instead
            // of being read as a flag.
            argv.push("--", text);
        }

        // Released in reverse order, so a sequence reads like a real chord in a
        // log. wtype would drop them on exit regardless.
        for (let i = mods.length - 1; i >= 0; i--)
            argv.push("-m", mods[i]);

        return argv;
    }

    function send(key: var): void {
        const s = root.spec(key);
        if (s.a !== undefined) {
            root.action(s);
            return;
        }

        const argv = root.argvFor(key);
        if (argv.length === 0)
            return;

        Quickshell.execDetached(argv);
        root.clearOneShots();
    }

    function action(s: var): void {
        switch (s.a) {
        case "shift":
        case "ctrl":
        case "alt":
        case "logo":
            root.toggleMod(s.a);
            break;
        case "layer":
            root.layer = root.layer === 0 ? 1 : 0;
            break;
        case "hide":
            root.dismiss();
            break;
        }
    }

    // `qs -c qshell ipc call osk toggle` — the keybind hook, and the way back
    // when the shell has guessed wrong and the keyboard you would fix it with
    // is the one that is not plugged in.
    IpcHandler {
        target: "osk"

        function toggle(): string {
            root.toggle();
            return root.active ? "shown" : "hidden";
        }

        // open/close, not show/hide: `show` is a real `qs ipc` subcommand, so
        // `qs ipc call osk show` never reaches the handler — the CLI prints
        // the target listing instead and returns success. The launcher's IPC
        // uses open/close for the same reason.
        function open(): string {
            root.show();
            return "shown";
        }

        function close(): string {
            root.dismiss();
            return "hidden";
        }

        function mode(m: string): string {
            Settings.setOsk(m);
            return Settings.osk;
        }

        // Why the keyboard is or isn't up. Every input to that decision in one
        // line, because "the OSK didn't appear" has six possible causes and
        // guessing between them from the outside is miserable.
        function status(): string {
            return JSON.stringify({
                active: root.active,
                wanted: root.wanted,
                mode: Settings.osk,
                manual: root.manual,
                tablet: Tablet.tablet,
                focusAvailable: root.focusAvailable,
                textFocus: root.textFocus,
                shellFieldFocused: root.shellFieldFocused,
                purpose: root.purpose
            });
        }
    }
}
