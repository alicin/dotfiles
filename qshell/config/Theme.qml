pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Color themes. Same contract as the old AGS shell (style/themes/*.scss): the
// bar is transparent chrome drawn over the wallpaper, surfaces (launcher) are
// opaque-ish panels using the palette proper. Add a theme: copy a block, keep
// every key, change values, then set it in settings.json or via
// `qs -c qshell ipc call theme set <name>`.
Singleton {
    id: root

    readonly property var themes: ({
            // Palette reference: https://catppuccin.com/palette (latte)
            "catppuccin-latte": {
                barFg: "#ffffff",
                barFgDim: "#adffffff",
                moduleHoverBg: "#24ffffff",
                moduleActiveBg: "#3dffffff",
                wsActiveBg: "#ffffff",
                wsActiveFg: "#8839ef", // mauve
                wsUrgentBg: "#d20f39", // red
                wsUrgentFg: "#ffffff",
                barOk: "#40a02b", //     green  (battery charging)
                barWarn: "#fe640b", //   peach
                barUrgent: "#d20f39", // red    (battery critical)
                surfaceBg: "#f7eff1f5", // base @ 0.97
                surfaceFg: "#4c4f69", //   text
                surfaceFgDim: "#6c6f85", // subtext0
                surfaceBorder: "#214c4f69",
                surfaceHoverBg: "#144c4f69",
                accent: "#8839ef", // mauve
                accentFg: "#ffffff",
                ok: "#40a02b",
                warn: "#df8e1d",
                urgent: "#d20f39",
                shadow: "#8c000000"
            },
            // Palette reference: https://catppuccin.com/palette (mocha)
            "catppuccin-mocha": {
                barFg: "#cdd6f4", //     text
                barFgDim: "#a6cdd6f4",
                moduleHoverBg: "#1fcdd6f4",
                moduleActiveBg: "#33cdd6f4",
                wsActiveBg: "#cba6f7", // mauve
                wsActiveFg: "#11111b", // crust
                wsUrgentBg: "#f38ba8", // red
                wsUrgentFg: "#11111b",
                barOk: "#a6e3a1",
                barWarn: "#fab387",
                barUrgent: "#f38ba8",
                surfaceBg: "#f71e1e2e", // base @ 0.97
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
            }
        })

    readonly property var active: themes[Settings.theme] ?? themes["catppuccin-latte"]
    readonly property list<string> available: Object.keys(themes)

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
