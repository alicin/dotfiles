pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Color themes. Same contract as the old AGS shell (style/themes/*.scss): the
// bar is transparent chrome drawn over the wallpaper, surfaces (launcher) are
// opaque-ish panels using the palette proper. Add a theme: copy a block, keep
// every key, change values, then set it in settings.json or via
// `qs -c qshell ipc call theme set <name>`.
//
// Two rules the palettes are checked against, both of which catch the mistake
// an upstream palette invites:
//
//   barFg is NOT the palette's text colour unless that colour happens to be
//   near-white. It is drawn on transparent chrome over an arbitrary wallpaper,
//   so it needs luminance, not fidelity — catppuccin-latte is a *light* theme
//   whose barFg is #ffffff for exactly this reason. Every theme here measures
//   at least 0.55 relative luminance (mocha's #cdd6f4 is 0.68, for scale).
//
//   The same goes for barOk / barWarn / barUrgent / barAwake, which is less
//   obvious and was wrong here for a while: a *light* theme's palette red is a
//   dark red, and the bar draws it over a wallpaper under a 75%-black drop
//   shadow (Bar.qml) that exists to make light glyphs pop and therefore buries
//   dark ones. Latte's critical-battery glyph measured 0.14 relative luminance
//   against its own 1.00 barFg. So every light theme takes these four from its
//   family's *dark* variant — the bar is chrome and looks the same in both,
//   and only the surfaces below it flip. Their `ok`/`warn`/`urgent` siblings,
//   which are drawn on panels, keep the light palette's dark values.
//
//   barAwake must be perceptually distinct from accent. The glyph it colours
//   is already accent-tinted whenever its menu is open, so a barAwake that is
//   merely a second shade of the accent makes "held awake" and "menu open" the
//   same colour saying different things.
//
// accentFg / wsActiveFg / wsUrgentFg sit ON a filled shape and are the ones an
// upstream palette won't give you — they all clear 4.5:1 against their fill.
Singleton {
    id: root

    readonly property var themes: ({
            // Palette reference: https://catppuccin.com/palette (latte)
            "catppuccin-latte": {
                label: "Latte",
                light: true,
                barFg: "#ffffff",
                barFgDim: "#adffffff",
                moduleHoverBg: "#24ffffff",
                moduleActiveBg: "#3dffffff",
                wsActiveBg: "#ffffff",
                wsActiveFg: "#8839ef",
                wsUrgentBg: "#d20f39",
                wsUrgentFg: "#ffffff",
                barOk: "#a6e3a1",  // green  (battery charging)
                barWarn: "#fab387",  // peach
                barUrgent: "#f38ba8",  // red    (battery critical)
                barAwake: "#f5c2e7",  // pink   (keep awake)
                surfaceBg: "#f7eff1f5",
                surfaceFg: "#4c4f69",
                surfaceFgDim: "#6c6f85",
                surfaceBorder: "#214c4f69",
                surfaceHoverBg: "#144c4f69",
                accent: "#8839ef",
                accentFg: "#ffffff",
                ok: "#40a02b",
                warn: "#df8e1d",
                urgent: "#d20f39",
                shadow: "#8c000000"
            },
            // Palette reference: https://catppuccin.com/palette (frappé) — all values verbatim upstream; barAwake is sky, not pink, so it cannot read as a second mauve
            "catppuccin-frappe": {
                label: "Frappé",
                light: false,
                barFg: "#c6d0f5",
                barFgDim: "#a6c6d0f5",
                moduleHoverBg: "#1fc6d0f5",
                moduleActiveBg: "#33c6d0f5",
                wsActiveBg: "#ca9ee6",
                wsActiveFg: "#232634",
                wsUrgentBg: "#e78284",
                wsUrgentFg: "#232634",
                barOk: "#a6d189",  // green  (battery charging)
                barWarn: "#ef9f76",  // peach
                barUrgent: "#e78284",  // red    (battery critical)
                barAwake: "#99d1db",  // pink   (keep awake)
                surfaceBg: "#f7303446",
                surfaceFg: "#c6d0f5",
                surfaceFgDim: "#a5adce",
                surfaceBorder: "#1ac6d0f5",
                surfaceHoverBg: "#12c6d0f5",
                accent: "#ca9ee6",
                accentFg: "#232634",
                ok: "#a6d189",
                warn: "#e5c890",
                urgent: "#e78284",
                shadow: "#b3000000"
            },
            // Palette reference: https://catppuccin.com/palette (macchiato) — all values verbatim upstream; barAwake is sky, not pink, so it cannot read as a second mauve
            "catppuccin-macchiato": {
                label: "Macchiato",
                light: false,
                barFg: "#cad3f5",
                barFgDim: "#a6cad3f5",
                moduleHoverBg: "#1fcad3f5",
                moduleActiveBg: "#33cad3f5",
                wsActiveBg: "#c6a0f6",
                wsActiveFg: "#181926",
                wsUrgentBg: "#ed8796",
                wsUrgentFg: "#181926",
                barOk: "#a6da95",  // green  (battery charging)
                barWarn: "#f5a97f",  // peach
                barUrgent: "#ed8796",  // red    (battery critical)
                barAwake: "#91d7e3",  // pink   (keep awake)
                surfaceBg: "#f724273a",
                surfaceFg: "#cad3f5",
                surfaceFgDim: "#a5adcb",
                surfaceBorder: "#1acad3f5",
                surfaceHoverBg: "#12cad3f5",
                accent: "#c6a0f6",
                accentFg: "#181926",
                ok: "#a6da95",
                warn: "#eed49f",
                urgent: "#ed8796",
                shadow: "#b3000000"
            },
            // Palette reference: https://catppuccin.com/palette (mocha)
            "catppuccin-mocha": {
                label: "Mocha",
                light: false,
                barFg: "#cdd6f4",
                barFgDim: "#a6cdd6f4",
                moduleHoverBg: "#1fcdd6f4",
                moduleActiveBg: "#33cdd6f4",
                wsActiveBg: "#cba6f7",
                wsActiveFg: "#11111b",
                wsUrgentBg: "#f38ba8",
                wsUrgentFg: "#11111b",
                barOk: "#a6e3a1",  // green  (battery charging)
                barWarn: "#fab387",  // peach
                barUrgent: "#f38ba8",  // red    (battery critical)
                barAwake: "#f5c2e7",  // pink   (keep awake)
                surfaceBg: "#f71e1e2e",
                surfaceFg: "#cdd6f4",
                surfaceFgDim: "#a6adc8",
                surfaceBorder: "#1acdd6f4",
                surfaceHoverBg: "#12cdd6f4",
                accent: "#cba6f7",
                accentFg: "#11111b",
                ok: "#a6e3a1",
                warn: "#f9e2af",
                urgent: "#f38ba8",
                shadow: "#b3000000"
            },
            // Palette reference: https://rosepinetheme.com/palette (rosé pine dawn); hexes verified against rose-pine/rose-pine-palette palette.json. accent/wsActiveFg (iris), wsUrgentBg (love) and warn (gold) are upstream hues darkened for WCAG — dawn's published accents are too light to carry white text or to read as status text on base.
            "rose-pine-dawn": {
                label: "Rosé Pine Dawn",
                light: true,
                barFg: "#ffffff",
                barFgDim: "#adffffff",
                moduleHoverBg: "#24ffffff",
                moduleActiveBg: "#3dffffff",
                wsActiveBg: "#ffffff",
                wsActiveFg: "#785f95",
                wsUrgentBg: "#a54f68",
                wsUrgentFg: "#ffffff",
                barOk: "#9ccfd8",  // green  (battery charging)
                barWarn: "#f6c177",  // peach
                barUrgent: "#eb6f92",  // red    (battery critical)
                barAwake: "#ebbcba",  // pink   (keep awake)
                surfaceBg: "#f7faf4ed",
                surfaceFg: "#464261",
                surfaceFgDim: "#797593",
                surfaceBorder: "#21464261",
                surfaceHoverBg: "#14464261",
                accent: "#785f95",
                accentFg: "#ffffff",
                ok: "#286983",
                warn: "#b06d12",
                urgent: "#b4637a",
                shadow: "#8c000000"
            },
            // Palette reference: https://rosepinetheme.com/palette (rosé pine moon); hexes verified against rose-pine/rose-pine-palette palette.json. ok/barOk use foam, not pine, to match the pale status set the dark bar expects.
            "rose-pine-moon": {
                label: "Rosé Pine Moon",
                light: false,
                barFg: "#e0def4",
                barFgDim: "#a6e0def4",
                moduleHoverBg: "#1fe0def4",
                moduleActiveBg: "#33e0def4",
                wsActiveBg: "#c4a7e7",
                wsActiveFg: "#232136",
                wsUrgentBg: "#eb6f92",
                wsUrgentFg: "#232136",
                barOk: "#9ccfd8",  // green  (battery charging)
                barWarn: "#f6c177",  // peach
                barUrgent: "#eb6f92",  // red    (battery critical)
                barAwake: "#ea9a97",  // pink   (keep awake)
                surfaceBg: "#f7232136",
                surfaceFg: "#e0def4",
                surfaceFgDim: "#908caa",
                surfaceBorder: "#1ae0def4",
                surfaceHoverBg: "#12e0def4",
                accent: "#c4a7e7",
                accentFg: "#232136",
                ok: "#9ccfd8",
                warn: "#f6c177",
                urgent: "#eb6f92",
                shadow: "#b3000000"
            },
            // Palette reference: https://rosepinetheme.com/palette (rosé pine — main); hexes verified against rose-pine/rose-pine-palette palette.json. ok/barOk use foam, not pine, so the charging/success tint stays legible on a bar over a dark wallpaper.
            "rose-pine": {
                label: "Rosé Pine",
                light: false,
                barFg: "#e0def4",
                barFgDim: "#a6e0def4",
                moduleHoverBg: "#1fe0def4",
                moduleActiveBg: "#33e0def4",
                wsActiveBg: "#c4a7e7",
                wsActiveFg: "#191724",
                wsUrgentBg: "#eb6f92",
                wsUrgentFg: "#191724",
                barOk: "#9ccfd8",  // green  (battery charging)
                barWarn: "#f6c177",  // peach
                barUrgent: "#eb6f92",  // red    (battery critical)
                barAwake: "#ebbcba",  // pink   (keep awake)
                surfaceBg: "#f7191724",
                surfaceFg: "#e0def4",
                surfaceFgDim: "#908caa",
                surfaceBorder: "#1ae0def4",
                surfaceHoverBg: "#12e0def4",
                accent: "#c4a7e7",
                accentFg: "#191724",
                ok: "#9ccfd8",
                warn: "#f6c177",
                urgent: "#eb6f92",
                shadow: "#b3000000"
            },
            // Palette reference: Tokyo Night Day — folke/tokyonight.nvim palette, https://github.com/folke/tokyonight.nvim/blob/main/extras/lua/tokyonight_day.lua; fg/blue/red darkened along their own hue for WCAG (upstream fg #3760bf is only 4.52:1 on bg #e1e2e7)
            "tokyo-night-day": {
                label: "Tokyo Night Day",
                light: true,
                barFg: "#ffffff",
                barFgDim: "#adffffff",
                moduleHoverBg: "#24ffffff",
                moduleActiveBg: "#3dffffff",
                wsActiveBg: "#ffffff",
                wsActiveFg: "#276ac6",
                wsUrgentBg: "#cb2354",
                wsUrgentFg: "#ffffff",
                barOk: "#9ece6a",  // green  (battery charging)
                barWarn: "#ff9e64",  // peach
                barUrgent: "#f7768e",  // red    (battery critical)
                barAwake: "#ff007c",  // pink   (keep awake)
                surfaceBg: "#f7e1e2e7",
                surfaceFg: "#254182",
                surfaceFgDim: "#515f92",
                surfaceBorder: "#21254182",
                surfaceHoverBg: "#14254182",
                accent: "#276ac6",
                accentFg: "#ffffff",
                ok: "#587539",
                warn: "#8c6c3e",
                urgent: "#c64343",
                shadow: "#8c000000"
            },
            // Palette reference: Tokyo Night (night) — folke/tokyonight.nvim palette, verified against https://github.com/folke/tokyonight.nvim/blob/main/extras/lua/tokyonight_night.lua
            "tokyo-night": {
                label: "Tokyo Night",
                light: false,
                barFg: "#c0caf5",
                barFgDim: "#a6c0caf5",
                moduleHoverBg: "#1fc0caf5",
                moduleActiveBg: "#33c0caf5",
                wsActiveBg: "#7aa2f7",
                wsActiveFg: "#16161e",
                wsUrgentBg: "#f7768e",
                wsUrgentFg: "#16161e",
                barOk: "#9ece6a",  // green  (battery charging)
                barWarn: "#ff9e64",  // peach
                barUrgent: "#f7768e",  // red    (battery critical)
                barAwake: "#ff007c",  // pink   (keep awake)
                surfaceBg: "#f71a1b26",
                surfaceFg: "#c0caf5",
                surfaceFgDim: "#a9b1d6",
                surfaceBorder: "#1ac0caf5",
                surfaceHoverBg: "#12c0caf5",
                accent: "#7aa2f7",
                accentFg: "#16161e",
                ok: "#9ece6a",
                warn: "#e0af68",
                urgent: "#f7768e",
                shadow: "#b3000000"
            },
            // Palette reference: gruvbox light, medium contrast (light0 #fbf1c7) — https://github.com/morhetz/gruvbox
            "gruvbox-light": {
                label: "Gruvbox Light",
                light: true,
                barFg: "#ffffff",
                barFgDim: "#adffffff",
                moduleHoverBg: "#24ffffff",
                moduleActiveBg: "#3dffffff",
                wsActiveBg: "#ffffff",
                wsActiveFg: "#076678",
                wsUrgentBg: "#cc241d",
                wsUrgentFg: "#ffffff",
                barOk: "#b8bb26",  // green  (battery charging)
                barWarn: "#fe8019",  // peach
                barUrgent: "#fb4934",  // red    (battery critical)
                barAwake: "#d3869b",  // pink   (keep awake)
                surfaceBg: "#f7fbf1c7",
                surfaceFg: "#3c3836",
                surfaceFgDim: "#665c54",
                surfaceBorder: "#213c3836",
                surfaceHoverBg: "#143c3836",
                accent: "#076678",
                accentFg: "#fbf1c7",
                ok: "#79740e",
                warn: "#b57614",
                urgent: "#9d0006",
                shadow: "#8c000000"
            },
            // Palette reference: gruvbox dark, medium contrast (dark0 #282828) — https://github.com/morhetz/gruvbox
            "gruvbox-dark": {
                label: "Gruvbox Dark",
                light: false,
                barFg: "#ebdbb2",
                barFgDim: "#a6ebdbb2",
                moduleHoverBg: "#1febdbb2",
                moduleActiveBg: "#33ebdbb2",
                wsActiveBg: "#83a598",
                wsActiveFg: "#1d2021",
                wsUrgentBg: "#fb4934",
                wsUrgentFg: "#1d2021",
                barOk: "#b8bb26",  // green  (battery charging)
                barWarn: "#fe8019",  // peach
                barUrgent: "#fb4934",  // red    (battery critical)
                barAwake: "#d3869b",  // pink   (keep awake)
                surfaceBg: "#f7282828",
                surfaceFg: "#ebdbb2",
                surfaceFgDim: "#a89984",
                surfaceBorder: "#21ebdbb2",
                surfaceHoverBg: "#14ebdbb2",
                accent: "#83a598",
                accentFg: "#1d2021",
                ok: "#b8bb26",
                warn: "#fabd2f",
                urgent: "#fb4934",
                shadow: "#b3000000"
            },
            // Palette reference: https://github.com/sainnhe/everforest/blob/master/palette.md (light, medium) — blue/red/green/yellow darkened from upstream (#3a94c5/#f85552/#8da101/#dfa000) to clear 4.5:1; bar-only tints stay upstream
            "everforest-light": {
                label: "Everforest Light",
                light: true,
                barFg: "#ffffff",
                barFgDim: "#adffffff",
                moduleHoverBg: "#24ffffff",
                moduleActiveBg: "#3dffffff",
                wsActiveBg: "#ffffff",
                wsActiveFg: "#5c6a72",
                wsUrgentBg: "#d04643",
                wsUrgentFg: "#ffffff",
                barOk: "#a7c080",  // green  (battery charging)
                barWarn: "#e69875",  // peach
                barUrgent: "#e67e80",  // red    (battery critical)
                barAwake: "#d699b6",  // pink   (keep awake)
                surfaceBg: "#f7fdf6e3",
                surfaceFg: "#5c6a72",
                surfaceFgDim: "#829181",
                surfaceBorder: "#215c6a72",
                surfaceHoverBg: "#145c6a72",
                accent: "#307da7",
                accentFg: "#ffffff",
                ok: "#697801",
                warn: "#956900",
                urgent: "#d04643",
                shadow: "#8c000000"
            },
            // Palette reference: https://github.com/sainnhe/everforest/blob/master/palette.md (dark, medium) — every value verbatim upstream, no deviations
            "everforest-dark": {
                label: "Everforest Dark",
                light: false,
                barFg: "#d3c6aa",
                barFgDim: "#a6d3c6aa",
                moduleHoverBg: "#1fd3c6aa",
                moduleActiveBg: "#33d3c6aa",
                wsActiveBg: "#7fbbb3",
                wsActiveFg: "#232a2e",
                wsUrgentBg: "#e67e80",
                wsUrgentFg: "#232a2e",
                barOk: "#a7c080",  // green  (battery charging)
                barWarn: "#e69875",  // peach
                barUrgent: "#e67e80",  // red    (battery critical)
                barAwake: "#d699b6",  // pink   (keep awake)
                surfaceBg: "#f72d353b",
                surfaceFg: "#d3c6aa",
                surfaceFgDim: "#9da9a0",
                surfaceBorder: "#1ad3c6aa",
                surfaceHoverBg: "#12d3c6aa",
                accent: "#7fbbb3",
                accentFg: "#232a2e",
                ok: "#a7c080",
                warn: "#dbbc7f",
                urgent: "#e67e80",
                shadow: "#b3000000"
            },
            // Palette reference: Nord palette (Polar Night / Snow Storm / Frost / Aurora) — https://www.nordtheme.com/docs/colors-and-palettes (wsUrgentBg is nord11 darkened to L=46% so the Snow Storm label clears AA)
            "nord": {
                label: "Nord",
                light: false,
                barFg: "#eceff4",
                barFgDim: "#a6eceff4",
                moduleHoverBg: "#1feceff4",
                moduleActiveBg: "#33eceff4",
                wsActiveBg: "#88c0d0",
                wsActiveFg: "#2e3440",
                wsUrgentBg: "#a7444d",
                wsUrgentFg: "#eceff4",
                barOk: "#a3be8c",  // green  (battery charging)
                barWarn: "#d08770",  // peach
                barUrgent: "#bf616a",  // red    (battery critical)
                barAwake: "#b48ead",  // pink   (keep awake)
                surfaceBg: "#f72e3440",
                surfaceFg: "#eceff4",
                surfaceFgDim: "#81a1c1",
                surfaceBorder: "#1feceff4",
                surfaceHoverBg: "#14eceff4",
                accent: "#88c0d0",
                accentFg: "#2e3440",
                ok: "#a3be8c",
                warn: "#ebcb8b",
                urgent: "#bf616a",
                shadow: "#b3000000"
            },
            // Palette reference: Dracula official palette — https://draculatheme.com/contribute (surfaceFgDim is Comment #6272a4 lightened to L=66% for AA on the surface)
            "dracula": {
                label: "Dracula",
                light: false,
                barFg: "#f8f8f2",
                barFgDim: "#a6f8f8f2",
                moduleHoverBg: "#1ff8f8f2",
                moduleActiveBg: "#33f8f8f2",
                wsActiveBg: "#bd93f9",
                wsActiveFg: "#282a36",
                wsUrgentBg: "#ff5555",
                wsUrgentFg: "#282a36",
                barOk: "#50fa7b",  // green  (battery charging)
                barWarn: "#ffb86c",  // peach
                barUrgent: "#ff5555",  // red    (battery critical)
                barAwake: "#ff79c6",  // pink   (keep awake)
                surfaceBg: "#f7282a36",
                surfaceFg: "#f8f8f2",
                surfaceFgDim: "#919cbf",
                surfaceBorder: "#1ff8f8f2",
                surfaceHoverBg: "#14f8f8f2",
                accent: "#bd93f9",
                accentFg: "#282a36",
                ok: "#50fa7b",
                warn: "#f1fa8c",
                urgent: "#ff5555",
                shadow: "#b3000000"
            },
            // Palette reference: Kanagawa wave — rebelot/kanagawa.nvim palette, verified against https://github.com/rebelot/kanagawa.nvim/blob/master/lua/kanagawa/colors.lua
            "kanagawa": {
                label: "Kanagawa",
                light: false,
                barFg: "#dcd7ba",
                barFgDim: "#a6dcd7ba",
                moduleHoverBg: "#1fdcd7ba",
                moduleActiveBg: "#33dcd7ba",
                wsActiveBg: "#7e9cd8",
                wsActiveFg: "#16161d",
                wsUrgentBg: "#ff5d62",
                wsUrgentFg: "#16161d",
                barOk: "#98bb6c",  // green  (battery charging)
                barWarn: "#ffa066",  // peach
                barUrgent: "#ff5d62",  // red    (battery critical)
                barAwake: "#d27e99",  // pink   (keep awake)
                surfaceBg: "#f71f1f28",
                surfaceFg: "#dcd7ba",
                surfaceFgDim: "#c8c093",
                surfaceBorder: "#1adcd7ba",
                surfaceHoverBg: "#12dcd7ba",
                accent: "#7e9cd8",
                accentFg: "#16161d",
                ok: "#98bb6c",
                warn: "#e6c384",
                urgent: "#ff5d62",
                shadow: "#b3000000"
            }
        })

    readonly property var active: themes[Settings.theme] ?? themes["catppuccin-latte"]
    readonly property list<string> available: Object.keys(themes)

    // Whether the *surfaces* are light. Not derivable from the theme's name —
    // "rose-pine-dawn" and "tokyo-night-day" are both light and neither says
    // so — and not derivable from `barFg` either, which is a light off-white in
    // every theme because it's drawn over the wallpaper rather than over a
    // panel. Anything picking a sun-or-moon glyph wants this.
    readonly property bool isLight: active.light ?? false

    // Human name for a theme key. The keys are family-prefixed so they sort
    // into families in the picker, but "catppuccin-macchiato" is not what
    // anyone calls it, and the old trick of taking the last dash-segment turns
    // "rose-pine" into "Pine" and "tokyo-night-day" into "Day".
    function label(name: string): string {
        return themes[name]?.label ?? name;
    }

    // Black or white, whichever is legible on `fill`. For glyphs drawn on a
    // themed *fill* rather than on a surface — a charging bolt on barOk, a
    // count on an urgent pill — where borrowing a token like accentFg means
    // borrowing a contrast guarantee made against a different colour entirely.
    //
    // WCAG relative luminance against the 0.179 split, not the cheaper
    // 0.299/0.587/0.114 perceptual average: across these sixteen palettes the
    // average bottoms out at 2.53:1 (gruvbox-light's barWarn) while this
    // matches picking the better of the two by measurement exactly, worst case
    // 5.13:1. `color.r/g/b` arrive gamma-encoded, hence the linearisation.
    function contrastFg(fill: color): color {
        const f = c => c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
        const l = 0.2126 * f(fill.r) + 0.7152 * f(fill.g) + 0.0722 * f(fill.b);
        return l > 0.179 ? "#000000" : "#ffffff";
    }

    // ── Bar chrome ──
    readonly property color barFg: active.barFg
    readonly property color barFgDim: active.barFgDim
    readonly property color moduleHoverBg: active.moduleHoverBg
    readonly property color moduleActiveBg: active.moduleActiveBg

    // ── Workspace pills ──
    readonly property color wsActiveBg: active.wsActiveBg
    readonly property color wsActiveFg: active.wsActiveFg
    readonly property color wsUrgentBg: active.wsUrgentBg
    readonly property color wsUrgentFg: active.wsUrgentFg

    // ── State accents on the bar ──
    readonly property color barOk: active.barOk
    readonly property color barWarn: active.barWarn
    readonly property color barUrgent: active.barUrgent

    // Keep Awake, on the Control Center glyph. Its own colour rather than the
    // accent: the accent is mauve in both themes, which is what the glyph
    // already looks like when a menu is open — "held awake" has to read as a
    // different fact, not a slightly different purple.
    readonly property color barAwake: active.barAwake

    // ── Privacy badge fills ──
    // Deliberately *not* per-theme. These are safety indicators whose whole job
    // is to be unmistakable, and macOS keeps its camera/mic dots identical in
    // light and dark for exactly that reason. They also have to carry a white
    // glyph, which barOk/barWarn can't — those are foreground tints, and their
    // mocha variants are pale pastels meant to sit on a dark bar.
    // Open Color green 8 / orange 8 / blue 8 — one ramp, so the three read as a
    // set of lights rather than three unrelated colours.
    //
    // Their white glyph measures 3.45:1, 2.48:1 and 5.02:1 respectively. Only
    // the last clears WCAG's 3:1 floor for non-text with room to spare, and
    // amber does not clear it at all — but these are 15px *filled badges*
    // whose job is to be spotted in peripheral vision, where hue and the fact
    // that something appeared do the work, and every platform that ships a mic
    // indicator uses this same amber. Recorded rather than quietly fixed: the
    // number is bad and the choice is still deliberate.
    readonly property color privacyCam: "#2f9e44"
    readonly property color privacyMic: "#f08c00"
    // Blue because that is what screen sharing already wears everywhere else,
    // and because green and amber were taken by the two lights it sits beside.
    readonly property color privacyCast: "#1971c2"

    // ── Surfaces (launcher) ──
    readonly property color surfaceBg: active.surfaceBg
    readonly property color surfaceFg: active.surfaceFg
    readonly property color surfaceFgDim: active.surfaceFgDim
    readonly property color surfaceBorder: active.surfaceBorder
    readonly property color surfaceHoverBg: active.surfaceHoverBg

    // ── Accents on surfaces ──
    readonly property color accent: active.accent

    // NOT `onAccent`: QML parses a property whose name is `on` + uppercase as a
    // signal handler, so the binding is silently dropped and the property keeps
    // colorable-default black. Cost us an afternoon — don't rename it back.
    readonly property color accentFg: active.accentFg
    readonly property color ok: active.ok
    readonly property color warn: active.warn
    readonly property color urgent: active.urgent

    // ── Elevation ──
    readonly property color shadow: active.shadow
}
