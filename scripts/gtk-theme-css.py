#!/usr/bin/env python3
"""Generate GTK 3 and GTK 4 colour overrides for a qshell theme.

Until this existed, all sixteen themes collapsed into two GTK looks: theme-sync
set `adw-gtk3` or `adw-gtk3-dark` and the portal's light/dark preference, so a
Nautilus window looked identical under Gruvbox and under Nord.

The palette is DERIVED FROM qshell/config/Theme.qml rather than typed out again
here. That file already carries every theme's real upstream values, and a second
hand-maintained copy is a second thing to get wrong — the two would disagree the
first time a colour was tuned in one of them. It also means GTK apps match the
shell exactly rather than approximately.

`surfaceBg` is stored as #AARRGGBB (Qt's order), so dropping the two alpha
digits is exactly the upstream base colour: #f7eff1f5 -> #eff1f5, which is
Catppuccin Latte's `base`. Everything else in Theme.qml is already #RRGGBB.

libadwaita is why this is CSS and not a theme name: GTK4 apps ignore
`gtk-theme-name` altogether and take their colours from the named-colour
definitions below, which is precisely why they only ever followed light/dark.
GTK3 apps read the same names through adw-gtk3, so one palette drives both.

    usage: gtk-theme-css.py <qshell-theme-name>
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
THEME_QML = os.path.join(ROOT, "qshell", "config", "Theme.qml")
TARGETS = [
    os.path.join(ROOT, "config", "gtk-3.0", "gtk.css"),
    os.path.join(ROOT, "config", "gtk-4.0", "gtk.css"),
]

HEADER = "/* Written by scripts/gtk-theme-css.py on every qshell theme change — do not edit. */\n"


# ── colour helpers ───────────────────────────────────────────────────────────
def rgb(hexstr):
    h = hexstr.lstrip("#")
    if len(h) == 8:          # #AARRGGBB from Qt — drop the alpha, keep RGB
        h = h[2:]
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def hexs(t):
    return "#%02x%02x%02x" % tuple(max(0, min(255, int(round(c)))) for c in t)


def mix(a, b, t):
    """a -> b by t. Used for every derived shade, so they stay in-family."""
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def luma(c):
    # Relative luminance, sRGB. Only used for contrast decisions.
    def lin(v):
        v /= 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    return 0.2126 * lin(c[0]) + 0.7152 * lin(c[1]) + 0.0722 * lin(c[2])


def contrast(a, b):
    la, lb = luma(a), luma(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def readable(fg, bg, want=4.5):
    """Nudge `fg` toward black or white until it is legible on `bg`.

    libadwaita separates the accent you FILL with (accent_bg_color, which gets
    white/black text of its own) from the accent you WRITE with (accent_color,
    on the window background). A pastel that looks right as a button fill is
    often unreadable as link text on a light theme, which is the failure this
    avoids — Latte's mauve on its near-white base is 3.1:1.
    """
    target = (0, 0, 0) if luma(bg) > 0.4 else (255, 255, 255)
    out = fg
    for i in range(1, 21):
        if contrast(out, bg) >= want:
            break
        out = mix(fg, target, i / 20)
    return out


# ── palette ──────────────────────────────────────────────────────────────────
def load(theme):
    src = open(THEME_QML).read()
    blocks = re.findall(r'"([a-z0-9-]+)":\s*\{(.*?)\n            \}', src, re.S)
    for name, body in blocks:
        if name != theme:
            continue
        kv = dict(re.findall(r'(\w+):\s*"(#[0-9a-fA-F]+)"', body))
        kv["_light"] = "light: true" in body
        return kv
    return None


def build(p):
    light = p["_light"]
    base = rgb(p["surfaceBg"])
    text = rgb(p["surfaceFg"])
    dim = rgb(p.get("surfaceFgDim", p["surfaceFg"]))
    accent = rgb(p["accent"])
    accent_fg = rgb(p.get("accentFg", "#ffffff"))
    ok = rgb(p.get("ok", "#2ec27e"))
    warn = rgb(p.get("warn", "#e5a50a"))
    bad = rgb(p.get("urgent", "#e01b24"))

    # Which way "further from the background" points. libadwaita's own light
    # theme puts views ABOVE the window (whiter); its dark theme puts them
    # BELOW (darker). Following that keeps depth cues reading the right way
    # round instead of inverting under dark themes.
    away = (255, 255, 255) if light else (0, 0, 0)
    toward = (0, 0, 0) if light else (255, 255, 255)

    view = mix(base, away, 0.55 if light else 0.35)
    card = mix(base, away, 0.35 if light else 0.22)
    header = mix(base, toward, 0.04)
    sidebar = mix(base, toward, 0.03)
    popover = mix(base, away, 0.30 if light else 0.28)
    dialog = card
    # A border that is a tint of the text rather than a grey: a neutral hairline
    # reads as dirt on a strongly-tinted ground like Everforest or Rosé Pine.
    border = mix(base, text, 0.18)

    c = {
        "accent_bg_color": accent,
        "accent_fg_color": accent_fg,
        "accent_color": readable(accent, base),
        "destructive_bg_color": bad,
        "destructive_fg_color": accent_fg,
        "destructive_color": readable(bad, base),
        "success_bg_color": ok,
        "success_fg_color": accent_fg,
        "success_color": readable(ok, base),
        "warning_bg_color": warn,
        # Warning fills are pale in every one of these palettes, so their label
        # is dark whatever the theme's own foreground is.
        "warning_fg_color": (0, 0, 0) if luma(warn) > 0.4 else (255, 255, 255),
        "warning_color": readable(warn, base),
        "error_bg_color": bad,
        "error_fg_color": accent_fg,
        "error_color": readable(bad, base),
        "window_bg_color": base,
        "window_fg_color": text,
        "view_bg_color": view,
        "view_fg_color": text,
        "headerbar_bg_color": header,
        "headerbar_fg_color": text,
        "headerbar_border_color": border,
        "headerbar_backdrop_color": base,
        "headerbar_shade_color": mix(base, (0, 0, 0), 0.12),
        "card_bg_color": card,
        "card_fg_color": text,
        "card_shade_color": mix(base, (0, 0, 0), 0.10),
        "dialog_bg_color": dialog,
        "dialog_fg_color": text,
        "popover_bg_color": popover,
        "popover_fg_color": text,
        "sidebar_bg_color": sidebar,
        "sidebar_fg_color": text,
        "sidebar_backdrop_color": base,
        "sidebar_shade_color": mix(base, (0, 0, 0), 0.10),
        "secondary_sidebar_bg_color": sidebar,
        "secondary_sidebar_fg_color": text,
        "thumbnail_bg_color": view,
        "thumbnail_fg_color": text,
        "shade_color": mix(base, (0, 0, 0), 0.18),
        "scrollbar_outline_color": border,
        # Not a libadwaita name, but adw-gtk3 and a lot of GTK3 CSS reach for a
        # dimmed foreground; defining it costs nothing and stops those falling
        # back to a grey that fights the palette.
        "dim_label_color": dim,
    }
    return c


def render(colors, theme, light):
    out = [HEADER,
           f"/* theme: {theme} ({'light' if light else 'dark'}) */\n\n"]
    for k, v in colors.items():
        out.append(f"@define-color {k} {hexs(v)};\n")
    return "".join(out)


def main():
    if len(sys.argv) < 2:
        print("usage: gtk-theme-css.py <qshell-theme-name>", file=sys.stderr)
        return 2
    theme = sys.argv[1]
    p = load(theme)
    if not p:
        print(f"gtk-theme-css: unknown theme '{theme}'", file=sys.stderr)
        return 1
    css = render(build(p), theme, p["_light"])
    for path in TARGETS:
        if not os.path.isdir(os.path.dirname(path)):
            continue
        # Temp + rename rather than truncate-in-place: a GTK app starting while
        # this is half-written would parse a truncated stylesheet and fall back
        # to defaults for the rest of its life.
        tmp = path + ".tmp"
        with open(tmp, "w") as fh:
            fh.write(css)
        os.replace(tmp, path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
