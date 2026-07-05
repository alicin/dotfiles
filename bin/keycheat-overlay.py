#!/usr/bin/env python3
"""keycheat — a slick keyboard-shortcuts overlay for Hyprland.

Parses config/hypr/lua/binds.lua (group headers `-- ▸ Name` + trailing `-- label`
comments) and renders it as a centered, dimmed, grouped cheat sheet on the overlay
layer. Click anywhere — or hit the toggle bind again (Super+/ · Alt+Shift+?) — to close.
"""
import os
import re
import ctypes

# gtk4-layer-shell MUST be loaded before Gtk pulls in libwayland-client, otherwise
# the layer surface silently falls back to a normal window. Preload it here.
ctypes.CDLL("libgtk4-layer-shell.so.0")

import gi  # noqa: E402

gi.require_version("Gtk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gtk, Gdk, Gtk4LayerShell as LayerShell  # noqa: E402

BINDS = os.path.join(os.path.dirname(__file__), "..", "config", "hypr", "lua", "binds.lua")
BINDS = os.path.normpath(BINDS)

ALIASES = {"M": "Super", "MS": "Super + Shift", "MC": "Super + Ctrl",
           "MCS": "Super + Ctrl + Shift", "mod": "Super"}

# Text-editing shortcuts live in Toshy (not binds.lua), so list them here by hand.
# Shown in physical keys: Alt = macOS Command (Toshy), Super = the word/Option modifier.
TEXT_GROUP = ("Text editing", [
    ("Super + ← →", "jump by word"),
    ("Super + Shift + ← →", "select word"),
    ("Alt + ← →", "line start / end"),
    ("Alt + Shift + ← →", "select to line"),
    ("Alt + C / V / X", "copy / paste / cut"),
    ("Alt + Z", "undo   ·   Alt+Shift+Z redo"),
    ("Alt + A / F / S", "all / find / save"),
])

# Prettify individual key tokens for display.
KEYMAP = {
    "Return": "↵", "slash": "/", "backslash": "\\", "grave": "`", "Space": "Space", "Delete": "Del", "Tab": "Tab",
    "left": "←", "right": "→", "up": "↑", "down": "↓",
    "mouse:272": "L-Click", "mouse:273": "R-Click", "mouse_down": "Scroll ↓", "mouse_up": "Scroll ↑",
    "XF86AudioRaiseVolume": "Vol +", "XF86AudioLowerVolume": "Vol −", "XF86AudioMute": "Mute",
    "XF86AudioMicMute": "Mic", "XF86AudioPlay": "▶", "XF86AudioStop": "■",
    "XF86AudioPause": "⏸", "XF86AudioPrev": "⏮", "XF86AudioNext": "⏭",
}


def _resolve_combo(expr):
    parts, out = expr.split(".."), []
    for p in parts:
        p = p.strip()
        if p in ALIASES:
            out.append(ALIASES[p])
        elif len(p) >= 2 and p[0] == '"' and p[-1] == '"':
            out.append(p[1:-1])
        else:
            return None
    return "".join(out).strip()


def _label(line):
    m = re.search(r".*\s--\s*(.+?)\s*$", line)
    return m.group(1) if m else None


def parse(path):
    groups, cur = [], None
    lines = open(path, encoding="utf-8").read().splitlines()
    i = 0
    while i < len(lines):
        s = lines[i].strip()
        m = re.match(r"^--\s*▸\s*(.+)$", s)
        if m:
            cur = (m.group(1).strip(), [])
            groups.append(cur)
            i += 1
            continue
        if s.startswith("for ws, key in pairs(ws_keys)"):
            if cur is not None:
                cur[1].append(("Super + 1…5 / F1…F7", "switch workspace 1–12"))
                cur[1].append(("Super + Shift + 1…5 / F1…F7", "move window to workspace"))
            while i < len(lines) and lines[i].strip() != "end":
                i += 1
            i += 1
            continue
        m = re.match(r"^hl\.bind\(\s*(.+?)\s*,", s)
        if m and cur is not None:
            combo = _resolve_combo(m.group(1))
            lab = _label(lines[i])
            if combo and lab:
                cur[1].append((combo, lab))
        i += 1
    # de-dup within a group (keeps first), drop empty groups
    out = []
    for name, rows in groups:
        seen, uniq = set(), []
        for combo, lab in rows:
            if (combo, lab) in seen:
                continue
            seen.add((combo, lab))
            uniq.append((combo, lab))
        if uniq:
            out.append((name, uniq))
    return out


CSS = b"""
window { background: transparent; }
.backdrop { background: alpha(#0b0b12, 0.62); }
.panel {
  background: linear-gradient(150deg, #1b1c2b, #14141f);
  border: 1px solid alpha(#cba6f7, 0.28);
  border-radius: 22px;
  padding: 26px 30px 30px 30px;
  box-shadow: 0 24px 70px alpha(#000, 0.55);
}
.title { color: #e7e6f4; font-size: 21px; font-weight: 800; }
.title .accent { color: #cba6f7; }
.hint  { color: #6f7192; font-size: 12px; }
.group { background: alpha(#ffffff, 0.035); border-radius: 14px; padding: 12px 14px; }
.group-title {
  color: #cba6f7; font-size: 11px; font-weight: 800;
  letter-spacing: 2px; margin-bottom: 6px;
}
.desc  { color: #b9bbd6; font-size: 13px; }
.plus  { color: #55576f; font-size: 12px; }
.chip {
  background: #2a2c40; color: #eceaffe6;
  border: 1px solid #3b3d57; border-bottom: 2px solid #26283b;
  border-radius: 7px; padding: 1px 8px;
  font-family: monospace; font-size: 12px; font-weight: 700;
}
.chip.mod { background: #322a4a; border-color: #4a3d6b; color: #d9c8ff; }
"""


def chip_row(combo):
    box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
    for i, tok in enumerate(combo.split(" + ")):
        if i:
            p = Gtk.Label(label="+")
            p.add_css_class("plus")
            box.append(p)
        lab = Gtk.Label(label=KEYMAP.get(tok, tok))
        lab.add_css_class("chip")
        if tok in ("Super", "Shift", "Ctrl", "Alt"):
            lab.add_css_class("mod")
        box.append(lab)
    return box


class KeyCheat(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.ali.keycheat")

    def do_activate(self):
        # A keyboard-NONE layer surface isn't counted as a held window, so the app
        # would exit right after present(). hold() keeps the main loop alive until
        # we explicitly quit (click, or the toggle bind's pkill).
        self.hold()

        prov = Gtk.CssProvider()
        prov.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), prov, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        win = Gtk.ApplicationWindow(application=self)
        LayerShell.init_for_window(win)
        LayerShell.set_layer(win, LayerShell.Layer.OVERLAY)
        LayerShell.set_keyboard_mode(win, LayerShell.KeyboardMode.NONE)
        for edge in (LayerShell.Edge.TOP, LayerShell.Edge.BOTTOM,
                     LayerShell.Edge.LEFT, LayerShell.Edge.RIGHT):
            LayerShell.set_anchor(win, edge, True)
        LayerShell.set_namespace(win, "keycheat")

        backdrop = Gtk.Box()
        backdrop.add_css_class("backdrop")
        backdrop.set_hexpand(True)
        backdrop.set_vexpand(True)

        panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        panel.add_css_class("panel")
        # hexpand/vexpand True + align CENTER = fill the monitor but paint the
        # card at its natural size, centered (GTK's reliable centering idiom).
        panel.set_hexpand(True)
        panel.set_vexpand(True)
        panel.set_halign(Gtk.Align.CENTER)
        panel.set_valign(Gtk.Align.CENTER)

        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=14)
        title = Gtk.Label(use_markup=True, halign=Gtk.Align.START, hexpand=True)
        title.set_markup('⌨  Keyboard <span foreground="#cba6f7" weight="bold">Shortcuts</span>')
        title.add_css_class("title")
        hint = Gtk.Label(label="Alt+Shift+?  ·  click to close", valign=Gtk.Align.CENTER)
        hint.add_css_class("hint")
        header.append(title)
        header.append(hint)
        panel.append(header)

        flow = Gtk.FlowBox(
            selection_mode=Gtk.SelectionMode.NONE, max_children_per_line=4,
            min_children_per_line=2, row_spacing=14, column_spacing=14, homogeneous=True,
        )
        for name, rows in [TEXT_GROUP] + parse(BINDS):
            g = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=7)
            g.add_css_class("group")
            gt = Gtk.Label(label=name.upper(), halign=Gtk.Align.START)
            gt.add_css_class("group-title")
            g.append(gt)
            for combo, lab in rows:
                r = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
                r.append(chip_row(combo))
                d = Gtk.Label(label=lab, halign=Gtk.Align.END, hexpand=True)
                d.add_css_class("desc")
                r.append(d)
                g.append(r)
            flow.insert(g, -1)

        scroller = Gtk.ScrolledWindow(propagate_natural_height=True, propagate_natural_width=True)
        scroller.set_max_content_height(920)
        scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroller.set_child(flow)
        panel.append(scroller)

        backdrop.append(panel)
        win.set_child(backdrop)

        click = Gtk.GestureClick()
        click.connect("released", lambda *a: self.quit())
        backdrop.add_controller(click)

        win.present()


if __name__ == "__main__":
    KeyCheat().run(None)
