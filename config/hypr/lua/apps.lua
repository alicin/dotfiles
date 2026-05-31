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
M.overview    = "qs ipc -c overview call overview toggle"

-- Menus.
M.menu  = "ali"
M.dmenu = "wofi -i --show dmenu"
-- Window switcher: select a client via wofi and focus it. Uses [==[ ]==]
-- (level-2 long brackets) because the shell snippet contains [[:blank:]].
M.wmenu = [==[hyprctl dispatch focuswindow address:"$(hyprctl -j clients | jq 'map("\(.workspace.id) ∴ \(.workspace.name) ┇ \(.title) ┇ \(.address)")' | sed "s/,$//; s/^\[//; s/^\]//; s/^[[:blank:]]*//; s/^\"//; s/\"$//" | grep -v "^$" | wofi -idO alphabetical | grep -o "0x.*$")"]==]

-- Status bar.
M.bar = "pkill hyprpanel || true; /usr/bin/hyprpanel"

-- On-screen volume/brightness indicator (wob).
M.onscreen_bar = [[bash ~/labs/dotfiles/scripts/wob.sh "#EB8A7DFF" "#2C2440FF"]]

-- Brightness.
M.brightness_up        = "brightnessctl -s set +10%"
M.brightness_down      = "brightnessctl -s set 10%-"
M.rog_brightness_up    = "/home/ali/labs/dotfiles/scripts/rog-backlight-control.sh up"
M.rog_brightness_down  = "/home/ali/labs/dotfiles/scripts/rog-backlight-control.sh down"

-- Keyboard backlight.
M.kb_brightness_up    = "brightnessctl --device='kbd_backlight' set +25"
M.kb_brightness_down  = "brightnessctl --device='kbd_backlight' set 25-"
M.kb_brightness_on    = "brightnessctl -rd asus::kbd_backlight"
M.kb_brightness_off   = "brightnessctl -sd asus::kbd_backlight set 0"

-- Audio.
M.sink_volume   = "pactl get-sink-volume @DEFAULT_SINK@ | grep '^Volume:' | cut -d / -f 2 | tr -d ' ' | sed 's/%//'"
M.source_volume = "pactl get-source-volume @DEFAULT_SOURCE@ | grep '^Volume:' | cut -d / -f 2 | tr -d ' ' | sed 's/%//'"
M.volume_down   = "pactl set-sink-volume @DEFAULT_SINK@ -5%"
M.volume_up     = "pactl set-sink-volume @DEFAULT_SINK@ +5%"
M.volume_mute   = "pactl set-sink-mute @DEFAULT_SINK@ toggle"
M.mic_mute      = "pactl set-source-mute @DEFAULT_SOURCE@ toggle"

-- Misc utilities.
M.colorpicker    = "hyprpicker | wl-copy"
M.clipboard      = "cliphist list | " .. M.dmenu .. " | cliphist decode | wl-copy"
M.clipboard_del  = "cliphist list | " .. M.dmenu .. " | cliphist delete"

-- Monitor / screenshot scripts.
M.toggle_edp         = "/home/ali/labs/dotfiles/bin/toggle-edp.sh"
M.toggle_edp_refresh = "/home/ali/labs/dotfiles/bin/toggle-edp-refresh.sh"
M.grab               = "/home/ali/labs/dotfiles/scripts/grab.sh"
M.record             = "/home/ali/labs/dotfiles/scripts/record.sh"

-- Lock / idle daemons (singleton: only spawn if not already running).
M.locking = "pidof hyprlock || hyprlock"
M.idle    = "pidof hypridle || hypridle"

return M
