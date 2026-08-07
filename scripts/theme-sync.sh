#!/usr/bin/env bash

# Propagate a qshell theme to everything else that has colors:
#
#     theme-sync.sh <qshell-theme-name>
#
# Called by qshell (services/ThemeSync.qml) whenever settings.json's theme
# changes — the launcher's `#` picker, `qs ipc call theme set`, or a hand
# edit all land here. Idempotent; running it twice is a no-op.
#
# What it drives, and how each one picks the change up live:
#
#   ghostty    THE terminal since 2026-08-07 (kitty had no touchscreen support
#              and no setting for it). Writes config/ghostty/current-theme, an
#              include the main config ends with, then SIGUSR2s every ghostty —
#              its config-reload signal, so open windows recolor in place.
#   kitty      same shape (current-theme.conf + SIGUSR1), kept working for as
#              long as kitty stays installed anywhere. Skipped when it isn't.
#   GTK 3/4    the real palette, as @define-color overrides written into
#              config/gtk-{3,4}.0/gtk.css by scripts/gtk-theme-css.py (which
#              derives them from qshell/config/Theme.qml, so GTK matches the
#              shell and there is one palette to maintain, not two). Plus
#              gsettings color-scheme + adw-gtk3(-dark) as the base.
#              MEASURED: light/dark follows the portal live, but the palette
#              itself is read once at app startup — a running app does not
#              re-read gtk.css, and poking gsettings does not make it. So a
#              theme change recolours GTK apps on their NEXT launch. Nautilus
#              in particular is single-instance, so `nautilus --new-window`
#              reuses the old daemon and its old colours; it needs a real kill.
#              sync-gnome-tweaks-to-gtk then mirrors it into settings.ini for
#              the bare-Hyprland case (see that script's header).
#   Chrome     nothing Chrome-specific: it watches the portal's
#              org.freedesktop.appearance color-scheme, which IS the gsettings
#              write above. Flips dark/light live.
#   VS Code    sets workbench.colorTheme in settings.json; Code watches the
#              file and applies instantly. Theme names verified against the
#              installed extensions' package.json.
#
# The shell's own surfaces are NOT handled here — qshell restyles itself from
# Theme.qml the instant the setting lands.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

THEME="${1:-}"
if [[ -z "${THEME}" ]]; then
    echo "usage: theme-sync.sh <qshell-theme-name>" >&2
    exit 2
fi

# One at a time: the launcher's theme picker stays open across picks, and
# overlapping instances interleaved their writes — kitty left on theme A with
# Code on theme B. Waiting rather than skipping: the LAST pick must win.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/theme-sync.lock"
flock 9

# Every run logs. This script is spawned DETACHED by the shell, so its output
# used to vanish — "GTK didn't change" was undiagnosable after the fact.
LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/qshell"
mkdir -p "$LOG_DIR"
exec >>"$LOG_DIR/theme-sync.log" 2>&1
echo "== $(date '+%F %T') theme=${THEME}"

# ── The mapping ──────────────────────────────────────────────────────────────
# qshell name → light? ; vscode label ; ghostty name. The kitty file shares
# the qshell slug (config/kitty/themes/<name>.conf), so it needs no column.
declare -A LIGHT VSCODE GHOSTTY
row() { LIGHT[$1]=$2; VSCODE[$1]=$3; GHOSTTY[$1]=$4; }

row catppuccin-latte      1 "Catppuccin Latte"      "Catppuccin Latte"
row catppuccin-frappe     0 "Catppuccin Frappé"     "Catppuccin Frappe"
row catppuccin-macchiato  0 "Catppuccin Macchiato"  "Catppuccin Macchiato"
row catppuccin-mocha      0 "Catppuccin Mocha"      "Catppuccin Mocha"
row rose-pine             0 "Rosé Pine"             "Rose Pine"
row rose-pine-moon        0 "Rosé Pine Moon"        "Rose Pine Moon"
row rose-pine-dawn        1 "Rosé Pine Dawn"        "Rose Pine Dawn"
row tokyo-night           0 "Tokyo Night"           "TokyoNight"
row tokyo-night-day       1 "Tokyo Night Light"     "TokyoNight Day"
row gruvbox-dark          0 "Gruvbox Dark Medium"   "Gruvbox Dark"
row gruvbox-light         1 "Gruvbox Light Medium"  "Gruvbox Light"
row everforest-dark       0 "Everforest Dark"       "Everforest Dark Hard"
row everforest-light      1 "Everforest Light"      "Everforest Light Med"
row nord                  0 "Nord"                  "Nord"
row dracula               0 "Dracula Theme"         "Dracula"
row kanagawa              0 "Kanagawa"              "Kanagawa Wave"

if [[ -z "${VSCODE[$THEME]:-}" ]]; then
    echo "theme-sync: unknown theme '${THEME}'" >&2
    exit 1
fi

# ── ghostty ──────────────────────────────────────────────────────────────────
# Theme names are ghostty's own bundled set, verified against
# `ghostty +list-themes` on 1.3.1 — the earlier guesses were all wrong.
GHOSTTY_THEME_FILE="${DOTFILES_DIR}/config/ghostty/current-theme"
if [[ -f "${GHOSTTY_THEME_FILE}" ]]; then
    printf '# Written by scripts/theme-sync.sh on every qshell theme change — do not edit.\ntheme = %s\n' \
        "${GHOSTTY[$THEME]}" > "${GHOSTTY_THEME_FILE}"
    pkill -USR2 -x ghostty 2>/dev/null || true
fi

# ── kitty (only while it is still installed) ─────────────────────────────────
KITTY_DIR="${DOTFILES_DIR}/config/kitty"
if command -v kitty >/dev/null 2>&1 && [[ -f "${KITTY_DIR}/themes/${THEME}.conf" ]]; then
    printf 'include themes/%s.conf\n' "${THEME}" > "${KITTY_DIR}/current-theme.conf"
    # Reload every running kitty; -x matches the exact process name so this
    # can never wing something else.
    pkill -USR1 -x kitty 2>/dev/null || true
fi

# ── GTK colours ─────────────────────────────────────────────────────────────
# The palette itself, as @define-color overrides for GTK 3 and GTK 4. Without
# this the sixteen themes collapse into two GTK looks: adw-gtk3 vs
# adw-gtk3-dark. Derived from qshell/config/Theme.qml so GTK apps match the
# shell exactly and there is only one palette to maintain — see that script.
#
# Written BEFORE the gsettings writes below, because those are what make
# running apps re-read it.
if [[ -f "${DOTFILES_DIR}/scripts/gtk-theme-css.py" ]]; then
    python3 "${DOTFILES_DIR}/scripts/gtk-theme-css.py" "${THEME}" \
        || echo "theme-sync: GTK css generation failed; GTK colours left alone" >&2
fi

# ── GTK / portal (Chrome rides this) ────────────────────────────────────────
if command -v gsettings >/dev/null 2>&1; then
    # `|| gtk_fail=1`, not bare calls: under `set -e` a gsettings failure
    # (launched without a session bus) aborted the whole script here, leaving
    # VS Code and ghostty desynced from the targets already written above.
    # Each target degrades alone.
    gtk_fail=0
    if [[ "${LIGHT[$THEME]}" == "1" ]]; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' || gtk_fail=1
        gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3' || gtk_fail=1
    else
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || gtk_fail=1
        gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' || gtk_fail=1
    fi
    # Rose Pine icon + cursor sets follow light/dark (per ali): dark themes
    # get the dark set — the icons are neutral enough to sit under every
    # family. Guarded on the set actually being installed
    # (rose-pine-gtk-theme-full from the AUR; BreezeX cursors), so a
    # not-yet-provisioned machine keeps what it has rather than falling back
    # to hicolor soup.
    if [[ "${LIGHT[$THEME]}" == "1" ]]; then
        want_icons="rose-pine-dawn-icons"
        want_cursor="BreezeX-RosePineDawn-Linux"
    else
        want_icons="rose-pine-icons"
        want_cursor="BreezeX-RosePine-Linux"
    fi
    if [[ -d "/usr/share/icons/${want_icons}" || -d "${HOME}/.local/share/icons/${want_icons}" ]]; then
        gsettings set org.gnome.desktop.interface icon-theme "${want_icons}" || gtk_fail=1
    else
        echo "theme-sync: icon theme '${want_icons}' not installed; leaving icons alone"
    fi
    if [[ -d "/usr/share/icons/${want_cursor}" || -d "${HOME}/.local/share/icons/${want_cursor}" ]]; then
        gsettings set org.gnome.desktop.interface cursor-theme "${want_cursor}" || gtk_fail=1
    fi
    if [[ "${gtk_fail}" == "1" ]]; then
        echo "theme-sync: gsettings write failed (no session bus?) — GTK/Chrome not synced" >&2
    fi
    # Mirror into settings.ini for GTK apps launched without the portal.
    "${DOTFILES_DIR}/bin/sync-gnome-tweaks-to-gtk" 2>/dev/null || true
fi

# ── VS Code ──────────────────────────────────────────────────────────────────
# settings.json is JSONC (comments allowed), so a strict JSON round-trip could
# destroy it. Surgical: replace the existing workbench.colorTheme value, or
# insert the key after the opening brace.
CODE_SETTINGS="${HOME}/.config/Code/User/settings.json"
if [[ -f "${CODE_SETTINGS}" ]]; then
    VSCODE_THEME="${VSCODE[$THEME]}" python3 - "$CODE_SETTINGS" <<'PY'
import os, re, sys

path = sys.argv[1]
theme = os.environ["VSCODE_THEME"]
src = open(path).read()

pattern = r'("workbench\.colorTheme"\s*:\s*)"(?:[^"\\]|\\.)*"'
if re.search(pattern, src):
    out = re.sub(pattern, lambda m: m.group(1) + f'"{theme}"', src, count=1)
else:
    brace = src.find("{")
    if brace < 0:
        sys.exit(0)
    out = src[:brace + 1] + f'\n  "workbench.colorTheme": "{theme}",' + src[brace + 1:]

if out != src:
    # Temp + rename, never truncate-in-place: Code watches this file and a
    # concurrent read mid-write saw it momentarily empty.
    tmp = path + ".theme-sync.tmp"
    with open(tmp, "w") as fh:
        fh.write(out)
    os.replace(tmp, path)
PY
fi
