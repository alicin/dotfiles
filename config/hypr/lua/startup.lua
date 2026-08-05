-- Autostart.
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
  -- Wallpaper. The bar starts further down, after the compositor's environment
  -- has been exported into systemd/DBus: when qshell is run through its user
  -- unit, that export is what gives it WAYLAND_DISPLAY.
  hl.exec_cmd("hyprpaper")

  -- GTK theming.
  -- GNOME Tweaks writes dconf/gsettings, but bare Hyprland sessions can launch
  -- GTK apps without the portal/xsettings bridge that applies those values.
  -- Mirror Tweaks values into GTK's settings.ini files instead of hardcoding
  -- theme/icon/font here.
  -- Points at the repo copy, not ~/.local/bin: that path is gitignored, so on a
  -- freshly provisioned machine the script simply would not be there and GTK
  -- apps would silently fall back to the Adwaita default.
  hl.exec_cmd("/home/ali/labs/dotfiles/bin/sync-gnome-tweaks-to-gtk")

  -- Daemons / one-shots.
  hl.exec_cmd(apps.idle)

  -- When Hyprland is launched by UWSM, finalize the compositor startup and
  -- export late compositor-provided variables into systemd/DBus activation.
  hl.exec_cmd("uwsm check is-active && uwsm finalize XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE || true")

  -- Harmless fallback for non-UWSM launches.
  hl.exec_cmd("dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE")

  -- Bar (and the notification daemon, and the launcher, and the OSD).
  hl.exec_cmd(apps.bar)
  -- clip-store.sh IS `cliphist store`, plus a note of which window had focus
  -- when the copy happened — the one thing a clipboard history needs beyond
  -- the content, and the one thing that cannot be reconstructed afterwards.
  -- The picker degrades to showing no source if the side file is missing.
  hl.exec_cmd("wl-paste --type text  --watch /home/ali/labs/dotfiles/scripts/clip-store.sh")
  hl.exec_cmd("wl-paste --type image --watch /home/ali/labs/dotfiles/scripts/clip-store.sh")

  hl.exec_cmd("nm-applet")
  hl.exec_cmd("pidof kdeconnectd || /usr/bin/kdeconnectd")
  hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
  -- hl.exec_cmd("qs -c overview")
end)
