-- Autostart (was startup.conf).
-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
--
-- Note: hl.exec_cmd() only spawns a process when called inside an event
-- callback (e.g. hl.on("hyprland.start", ...)) or via hl.dispatch from a bind.
-- At module top-level it's a no-op — that's why the old version of this file
-- silently failed to start hyprpanel and hyprpaper. Everything below now
-- runs on the start event, which fires once per Hyprland session.
--
-- This loses the "runs on every config reload" semantics that the old
-- `exec = ` directive had, but for our use case (singletons like hyprpanel,
-- hyprpaper, daemons) that's fine — and gsettings calls are idempotent so
-- running once at startup is sufficient.

local apps = require("lua.apps")

hl.on("hyprland.start", function()
  -- Bar + wallpaper.
  hl.exec_cmd(apps.bar)
  hl.exec_cmd("hyprpaper")

  -- GTK theming.
  hl.exec_cmd([[gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3"]])         -- GTK3
  hl.exec_cmd([[gsettings set org.gnome.desktop.interface color-scheme "prefer-light"]])  -- GTK4
  hl.exec_cmd([[gsettings set org.gnome.desktop.interface icon-theme 'rose-pine-icons']])

  -- Daemons / one-shots.
  hl.exec_cmd(apps.idle)
  hl.exec_cmd("dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP")
  hl.exec_cmd("wl-paste --type text  --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")

  hl.exec_cmd("nm-applet")
  hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
  -- hl.exec_cmd("qs -c overview")
end)
