-- Application & command strings shared by binds, startup, and host modules.
-- Returned as a table so consumers can `local apps = require("lua.apps")` and use `apps.term`.

local M = {}

-- Wallpaper (used by hyprpaper.conf, not Hyprland itself).
M.bg = os.getenv("HOME") .. "/.wallpaper/forest.jpg"

-- Terminals.
M.term                 = "kitty"
M.term_float           = M.term .. " --class=com.ali.floating_shell"
M.term_float_portrait  = M.term .. " --class=com.ali.floating_shell_portrait"

-- Core apps.
M.browser     = "google-chrome --disable-features=WaylandWpColorManagerV1"
M.filemanager = M.term_float .. " -e yazi"
M.calendar    = M.term_float .. " khal interactive"
M.editor      = "code"
M.overview    = "qs ipc -c qshell call overview toggle"

-- Menus.
-- M.menu  = "ali"
-- qshell launcher (caelestia-style panel from ~/labs/src/nullsector/j4rv15/qshell,
-- symlinked to ~/.config/quickshell/qshell). `toggle` closes it if already open.
M.menu  = "qs ipc -c qshell call launcher toggle"
-- Old wofi launcher, kept as fallback:
-- M.menu  = "pkill wofi || wofi --show drun --allow-images"
M.dmenu = "wofi -i --show dmenu"
-- Window switcher: the launcher's `/` mode — same panel, same fuzzy matcher,
-- windows ordered most-recently-focused (which the wofi pipeline below could
-- never do: `hyprctl clients` is in creation order). Pressing it again closes.
M.wmenu = "qs ipc -c qshell call launcher mode '/'"
-- Old wofi window switcher, kept as fallback. Uses [==[ ]==] (level-2 long
-- brackets) because the shell snippet contains [[:blank:]].
-- M.wmenu = [==[hyprctl dispatch focuswindow address:"$(hyprctl -j clients | jq 'map("\(.workspace.id) ∴ \(.workspace.name) ┇ \(.title) ┇ \(.address)")' | sed "s/,$//; s/^\[//; s/^\]//; s/^[[:blank:]]*//; s/^\"//; s/\"$//" | grep -v "^$" | wofi -idO alphabetical | grep -o "0x.*$")"]==]

-- Command palette and emoji picker: the same launcher, opened straight into a
-- prefix mode. Every verb in the palette already had a service behind it and
-- no way to reach it from the keyboard.
M.cmenu = "qs ipc -c qshell call launcher mode '>'"
M.emoji = "qs ipc -c qshell call launcher mode ':'"

-- Status bar: qshell (Quickshell shell in the j4rv15 repo). Same restart
-- semantics as the old hyprpanel line: kill any running instance, start fresh.
--
-- Prefers the systemd user unit when it is enabled, so the shell has a
-- supervisor — a crash otherwise silently takes the bar, the launcher, the OSD
-- *and* the notification daemon with it, with nothing to bring them back. To
-- turn that on once:
--     systemctl --user daemon-reload
--     systemctl --user enable --now qshell.service
-- Falls back to the plain launch when the unit isn't enabled, so this line
-- works either way and enabling it needs no config change.
M.bar = "systemctl --user is-enabled --quiet qshell.service && systemctl --user restart qshell.service || { qs kill -c qshell 2>/dev/null; qs -d -c qshell; }"

-- On-screen volume/brightness indicator (wob).
M.onscreen_bar = [[bash ~/labs/dotfiles/scripts/wob.sh "#EB8A7DFF" "#2C2440FF"]]

-- Brightness. Routed through qshell so its OSD reacts on the keypress: the
-- kernel gives no change notification to watch, so a shell that only polls
-- would show the bar late (or not at all). qs ipc exits non-zero when the
-- shell isn't running, so the standalone paths stay as a fallback and the keys
-- keep working with the bar dead.
--
-- The shell applies the same 1-100 logical scale as the script (mapped onto the
-- panel's useful ~80% of the HDR register), so the step size feels identical
-- either way.
M.brightness_up        = "qs ipc -c qshell call brightness up 2>/dev/null || brightnessctl -s set +10%"
M.brightness_down      = "qs ipc -c qshell call brightness down 2>/dev/null || brightnessctl -s set 10%-"
M.rog_brightness_up    = "qs ipc -c qshell call brightness up 2>/dev/null || /home/ali/labs/dotfiles/scripts/rog-backlight-control.sh up"
M.rog_brightness_down  = "qs ipc -c qshell call brightness down 2>/dev/null || /home/ali/labs/dotfiles/scripts/rog-backlight-control.sh down"

-- Keyboard backlight. Same deal; the ROG light is 0-3 with nothing in between,
-- so these step rather than scale, and the OSD draws segments not a bar.
M.kb_brightness_up    = "qs ipc -c qshell call brightness kbdUp 2>/dev/null || asusctl leds next"
M.kb_brightness_down  = "qs ipc -c qshell call brightness kbdDown 2>/dev/null || asusctl leds prev"
M.kb_brightness_on    = "brightnessctl -rd asus::kbd_backlight"
M.kb_brightness_off   = "brightnessctl -sd asus::kbd_backlight set 0"

-- Audio.
M.sink_volume   = "pactl get-sink-volume @DEFAULT_SINK@ | grep '^Volume:' | cut -d / -f 2 | tr -d ' ' | sed 's/%//'"
M.source_volume = "pactl get-source-volume @DEFAULT_SOURCE@ | grep '^Volume:' | cut -d / -f 2 | tr -d ' ' | sed 's/%//'"
-- wpctl with -l (limit) so repeated volume-up stops at exactly 100%.
M.volume_down   = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
M.volume_up     = "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"
M.volume_mute   = "pactl set-sink-mute @DEFAULT_SINK@ toggle"
M.mic_mute      = "pactl set-source-mute @DEFAULT_SOURCE@ toggle"

-- Misc utilities.
M.colorpicker    = "hyprpicker | wl-copy"
-- Clipboard history: qshell's picker (same cliphist store as before, so the
-- history carries over). Deleting an entry is Shift+Delete inside the panel,
-- which is why there's no separate clipboard_del binding any more.
M.clipboard      = "qs ipc -c qshell call clipboard toggle"
-- Old wofi pickers, kept as fallback:
-- M.clipboard     = "cliphist list | " .. M.dmenu .. " | cliphist decode | wl-copy"
-- M.clipboard_del = "cliphist list | " .. M.dmenu .. " | cliphist delete"

-- Monitor / screenshot scripts.
M.toggle_edp         = "/home/ali/labs/dotfiles/bin/toggle-edp.sh"
M.toggle_edp_refresh = "/home/ali/labs/dotfiles/bin/toggle-edp-refresh.sh"
M.relight_displays   = "/home/ali/labs/dotfiles/bin/relight-displays.sh"
-- Capture. Both go through the shell when it's up — only it can pull the bar
-- and toasts out of the picture first, dim around a recording region, and show
-- elapsed time — and fall back to the same scripts underneath when it isn't, so
-- the behaviour is identical either way. (Same idiom as the brightness keys.)
M.grab               = "qs -c qshell ipc call capture shot area 2>/dev/null || /home/ali/labs/dotfiles/scripts/screenshot.sh area"     -- macOS Cmd+Shift+4 style: area screenshot
-- The mode argument is REQUIRED even though only "full" is special-cased: an
-- arity mismatch makes `qs ipc call` print an error and exit *0*, so the `||`
-- fallback never runs and the key silently does nothing at all.
M.record             = "qs -c qshell ipc call capture record area 2>/dev/null || /home/ali/labs/dotfiles/scripts/screen_record.sh toggle"   -- macOS Cmd+Shift+5 style: area recording toggle
-- Whole-screen recording. The shell's recordFull() existed with no caller
-- anywhere; the fallback toggles the same script with no -g, so it records
-- everything rather than asking for a region.
M.record_full        = "qs -c qshell ipc call capture record full 2>/dev/null || "
  .. "{ SR=/home/ali/labs/dotfiles/scripts/screen_record.sh; "
  .. "[ \"$($SR status)\" = 'not recording' ] && $SR start || $SR stop; }"
-- Pause closes the current segment; stopping concatenates them (wf-recorder
-- has no pause signal — see screen_record.sh). One key does both directions.
M.record_pause       = "qs -c qshell ipc call capture pause 2>/dev/null || "
  .. "{ SR=/home/ali/labs/dotfiles/scripts/screen_record.sh; $SR pause || $SR resume; }"

-- Shell verbs that were previously mouse-only. Both announce themselves: the
-- profile change raises the OSD on its own, and DND is visible on the bell.
M.power_profile      = "qs -c qshell ipc call power cycle"
M.dnd                = "qs -c qshell ipc call notifs dnd"

-- Control Center, by page. Sound, Bluetooth and KDE Connect stopped having bar
-- modules of their own when the panel absorbed them, which left their pages
-- reachable only by opening the panel and clicking through — the IPC verbs have
-- existed since that refactor with nothing bound to them.
--
-- "control" is the home screen, and it routes through the same toggle as the
-- pages, so pressing it while a page is open navigates *back* instead of
-- dismissing the panel. That makes it the natural Esc-ward key inside the
-- submap as well as the way in.
M.control            = "qs -c qshell ipc call popouts toggle control"
M.control_audio      = "qs -c qshell ipc call popouts toggle audio"
M.control_bluetooth  = "qs -c qshell ipc call popouts toggle bluetooth"
M.control_kdeconnect = "qs -c qshell ipc call popouts toggle kdeconnect"
M.control_display    = "qs -c qshell ipc call popouts toggle display"
M.keycheat           = "/home/ali/labs/dotfiles/bin/keycheat"   -- shortcuts overlay (toggle)

-- Lock / idle daemons (singleton: only spawn if not already running).
M.locking = "pidof hyprlock || hyprlock"
M.idle    = "pidof hypridle || hypridle"

return M
