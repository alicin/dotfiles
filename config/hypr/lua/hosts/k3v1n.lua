-- k3v1n — tablet with eDP + occasional external LG 4K displays.

local apps = require("lua.apps")

-- ── Monitors ────────────────────────────────────────────────────────────────
hl.monitor({ output = "eDP-1", mode = "2560x1600@120", position = "0x0", scale = 1.333334 })
hl.monitor({
  output    = "desc:LG Electronics LG HDR 4K 0x0007807F",
  mode      = "3840x2160@60",
  position  = "0x-1080",
  scale     = 2,
})
hl.monitor({
  output    = "desc:LG Electronics LG HDR 4K 0x0007FDE4",
  mode      = "3840x2160@60",
  position  = "1920x-1700",
  scale     = 1.6666666,
  transform = 1,
})

-- ── Per-host workspaces (all on the tablet's eDP-1 by default) ──────────────
local edp = "eDP-1"
hl.workspace_rule({ workspace = "1", monitor = edp, default = true, persistent = true })
for i = 2, 9 do
  hl.workspace_rule({ workspace = tostring(i), monitor = edp, persistent = true })
end

-- ── Autostart ───────────────────────────────────────────────────────────────
hl.on("hyprland.start", function()
  hl.exec_cmd("/usr/bin/squeekboard")      -- on-screen keyboard
  hl.exec_cmd("corectrl --minimize-systray")
end)

-- ── Host-specific binds ─────────────────────────────────────────────────────
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(apps.brightness_up),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(apps.brightness_down), { locked = true, repeating = true })
hl.bind("SUPER + z",         hl.dsp.exec_cmd(apps.kb_brightness_down))
hl.bind("SUPER + SHIFT + z", hl.dsp.exec_cmd(apps.kb_brightness_up))
