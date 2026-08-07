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
#   kitty      writes current-theme.conf (an include kitty.conf already has)
#              and SIGUSR1s every kitty — kitty re-reads its config on that
#              signal, so open terminals recolor in place.
#   GTK 3/4    gsettings color-scheme + adw-gtk3(-dark). Libadwaita/GTK4 apps
#              follow the portal live; GTK3 apps pick it up on next launch.
#              sync-gnome-tweaks-to-gtk then mirrors it into settings.ini for
#              the bare-Hyprland case (see that script's header).
#   Chrome     nothing Chrome-specific: it watches the portal's
#              org.freedesktop.appearance color-scheme, which IS the gsettings
#              write above. Flips dark/light live.
#   VS Code    sets workbench.colorTheme in settings.json; Code watches the
#              file and applies instantly. Theme names verified against the
#              installed extensions' package.json.
#   ghostty    best-effort and UNVERIFIED — not installed on any host yet.
#              If it ever is: writes its theme line and SIGUSR2s it (its
#              config-reload signal). Names are ghostty's bundled set and may
#              need correcting on first contact with a real install.
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

row catppuccin-latte      1 "Catppuccin Latte"      "catppuccin-latte"
row catppuccin-frappe     0 "Catppuccin Frappé"     "catppuccin-frappe"
row catppuccin-macchiato  0 "Catppuccin Macchiato"  "catppuccin-macchiato"
row catppuccin-mocha      0 "Catppuccin Mocha"      "catppuccin-mocha"
row rose-pine             0 "Rosé Pine"             "rose-pine"
row rose-pine-moon        0 "Rosé Pine Moon"        "rose-pine-moon"
row rose-pine-dawn        1 "Rosé Pine Dawn"        "rose-pine-dawn"
row tokyo-night           0 "Tokyo Night"           "TokyoNight"
row tokyo-night-day       1 "Tokyo Night Light"     "TokyoNight Day"
row gruvbox-dark          0 "Gruvbox Dark Medium"   "GruvboxDark"
row gruvbox-light         1 "Gruvbox Light Medium"  "GruvboxLight"
row everforest-dark       0 "Everforest Dark"       "Everforest Dark - Med"
row everforest-light      1 "Everforest Light"      "Everforest Light - Med"
row nord                  0 "Nord"                  "nord"
row dracula               0 "Dracula Theme"         "Dracula"
row kanagawa              0 "Kanagawa"              "Kanagawa Wave"

if [[ -z "${VSCODE[$THEME]:-}" ]]; then
    echo "theme-sync: unknown theme '${THEME}'" >&2
    exit 1
fi

# ── kitty ────────────────────────────────────────────────────────────────────
KITTY_DIR="${DOTFILES_DIR}/config/kitty"
if [[ -f "${KITTY_DIR}/themes/${THEME}.conf" ]]; then
    printf 'include themes/%s.conf\n' "${THEME}" > "${KITTY_DIR}/current-theme.conf"
    # Reload every running kitty; -x matches the exact process name so this
    # can never wing something else.
    pkill -USR1 -x kitty 2>/dev/null || true
else
    echo "theme-sync: no kitty theme for '${THEME}'" >&2
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

# ── ghostty (best-effort; see header) ───────────────────────────────────────
GHOSTTY_CONF="${HOME}/.config/ghostty/config"
if command -v ghostty >/dev/null 2>&1 && [[ -f "${GHOSTTY_CONF}" ]]; then
    if grep -q '^theme *=' "${GHOSTTY_CONF}"; then
        sed -i "s/^theme *=.*/theme = ${GHOSTTY[$THEME]}/" "${GHOSTTY_CONF}"
    else
        printf 'theme = %s\n' "${GHOSTTY[$THEME]}" >> "${GHOSTTY_CONF}"
    fi
    pkill -USR2 -x ghostty 2>/dev/null || true
fi
