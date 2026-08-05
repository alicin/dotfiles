-- Environment variables.
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

-- Apps.
hl.env("TERMINAL",          "kitty")
hl.env("EDITOR",            "code")
hl.env("FILE_BROWSER",      "yazi")
hl.env("BROWSER",           "google-chrome-stable")
hl.env("MOZ_ENABLE_WAYLAND", "1")

-- Backends.
hl.env("SDL_VIDEODRIVER",  "wayland")
hl.env("CLUTTER_BACKEND",  "wayland")

-- Qt.
hl.env("QT_QPA_PLATFORM",                    "wayland;xcb")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR",        "1")
hl.env("QT_SCALE_FACTOR",                    "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_QPA_PLATFORMTHEME",               "qt5ct")

-- GDK / GTK.
hl.env("GDK_SCALE",    "1")
hl.env("GDK_BACKEND",  "wayland,x11,*")
hl.env("GSK_RENDERER", "ngl")

-- Electron.
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")

-- XDG.
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE",    "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Cursor theme.
-- Keep Hyprland (hyprcursor), XWayland/libXcursor, GTK, and Qt apps at a readable size.
hl.env("HYPRCURSOR_THEME", "rose-pine-hyprcursor")
hl.env("HYPRCURSOR_SIZE",  "32")
hl.env("XCURSOR_THEME",    "BreezeX-RosePine-Linux")
hl.env("XCURSOR_SIZE",     "32")

-- GPU device pin (compositor).
-- Deliberately NOT set here. This file is shared by every host, and pinning
-- AQ_DRM_DEVICES to one machine's card is how you brick another one: the value
-- used to be hardcoded to ~/.config/hypr/igpu (a symlink to h4l9000's Intel
-- by-path node), which on a single-GPU AMD host resolves to nothing and gets
-- Aquamarine to report "Found no gpus" -> CBackend::create() failed -> crash
-- loop. Hosts that genuinely need a pin set it themselves; see
-- lua/hosts/h4l9000.lua. Single-GPU hosts want no pin at all so the compositor
-- picks the only card present.
--
-- The AUTHORITATIVE, supergfx-mode-aware GPU/game environment lives in
-- ~/.config/uwsm/env (sourced before the compositor launches; that is the path
-- tuigreet's remembered session uses).
