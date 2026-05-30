-- Window rules.
-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/

-- ── Float everything by default; tiled exceptions come further down ──────────
hl.window_rule({ match = { class = ".*" }, float = true })

-- ── Floating utilities, dialogs, settings panels ─────────────────────────────
local float_classes = {
  "^(Rofi)$",
  "^(org.gnome.Calculator)$",
  "^(org.gnome.NautilusPreviewer)$",
  "^(org.gnome.TextEditor)$",
  "^(com.usebottles.bottles)$",
  "^(com-azefsw-audioconnect-desktop-app-MainKt)$",
  "^(steam)$",
  "^(eww)$",
  "^(pavucontrol)$",
  "^(nm-connection-editor)$",
  "^(blueberry.py)$",
  "^(org.gnome.Settings)$",
  "^(org.gnome.design.Palette)$",
  "^(Color Picker)$",
  "^(Network)$",
  "^(xdg-desktop-portal)$",
  "^(xdg-desktop-portal-gnome)$",
  "^(transmission-gtk)$",
  "^(ags)$",
  "^(CurseForge)$",
  "^(VirtualBox Manager)$",
  "^(org.corectrl.corectrl)$",
  "^(blueman-manager)$",
  "^(hyprland-share-picker)$",
  "^(mpv)$",
  "^(ascension launcher.exe)$",
  "^(net.lutris.Lutris)$",
  "^(xdg-desktop-portal-gtk)$",
}
for _, cls in ipairs(float_classes) do
  hl.window_rule({ match = { class = cls }, float = true })
end

-- Ascension launcher title-based match.
hl.window_rule({ match = { title = "^(Ascension launcher.exe)$" }, float = true })

-- Waydroid is fullscreen, not floating.
hl.window_rule({ match = { class = "^(Waydroid)$" }, fullscreen = true })

-- ── Named, sized floats ──────────────────────────────────────────────────────
hl.window_rule({
  name   = "floating_media_70",
  float  = true,
  size   = "(monitor_w*0.7) (monitor_h*0.7)",
  match  = { class = "^(imv|mpv|Picture-in-Picture)$" },
  center = true,
})

hl.window_rule({
  name   = "pulseaudio",
  float  = true,
  size   = "(monitor_w*0.5) (monitor_h*0.8)",
  match  = { class = "^(Pavucontrol|org.pulseaudio.pavucontrol)$" },
  center = true,
})

hl.window_rule({
  name   = "floating_pamac_60",
  float  = true,
  size   = "(monitor_w*0.6) (monitor_h*0.6)",
  match  = { class = "^(org.manjaro.pamac.manager)$" },
  center = true,
})

hl.window_rule({
  name   = "floating_nautilus_60",
  float  = true,
  size   = "768 756",
  match  = { class = "^(org.gnome.Nautilus)$" },
  center = true,
})

-- ── Terminal floats ──────────────────────────────────────────────────────────
hl.window_rule({
  name   = "floating_shell_60",
  float  = true,
  size   = "920 580",
  center = true,
  match  = { class = "^(com.ali.floating_shell)$" },
})

hl.window_rule({
  name   = "floating_shell_portrait",
  float  = true,
  size   = "(monitor_w*0.35) (monitor_h*0.8)",
  center = true,
  match  = { class = "^(com.ali.floating_shell_portrait)$" },
})

-- scrcpy pinned to laptop screen.
hl.window_rule({
  name    = "scrcpy_float_fix",
  float   = true,
  size    = "508 1125",
  center  = true,
  match   = { class = "^(scrcpy)$" },
  monitor = "eDP-1",
})

-- ── Misc ─────────────────────────────────────────────────────────────────────
-- No shadow on any floating window (cuts shadow render cost).
hl.window_rule({ match = { float = true }, no_shadow = true })

-- ── Special workspace assignments ────────────────────────────────────────────
hl.window_rule({
  match     = { title = "^(meet.google.com is sharing a window.)$" },
  workspace = "special:void silent",
})
hl.window_rule({
  match     = { class = "^(explorer.exe)$" },
  workspace = "special:void silent",
})

-- ── Tiled exceptions (override the catch-all float rule above) ───────────────
local tiled_classes = {
  -- Browsers.
  "^(firefox|Firefox|LibreWolf|librewolf|Floorp|floorp|Waterfox|waterfox)$",
  "^(google-chrome|chromium|Chromium|Brave-browser|brave-browser|microsoft-edge|vivaldi|Vivaldi|opera|Opera)$",
  -- Code editors / IDEs.
  "^(code|code-oss|VSCodium|vscodium|cursor|Cursor)$",
  -- Terminals.
  "^(kitty|Alacritty|alacritty|foot|foot-direct|footclient)$",
  "^(wezterm|org.wezfurlong.wezterm|WezTerm)$",
  "^(gnome-terminal|konsole|xterm|xterm-256color|tilix|Tilix)$",
}
for _, cls in ipairs(tiled_classes) do
  hl.window_rule({ match = { class = cls }, float = false })
end

-- World of Warcraft — fullscreen.
-- hl.window_rule({ match = { class = "^([Ww]ow[.-]?exe|[Ww]orld[Oo]f[Ww]arcraft)$" }, fullscreen = true })
-- hl.window_rule({ match = { title = "^(World of Warcraft)$" }, fullscreen = true })
