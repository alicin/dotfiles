-- h4l9000 — laptop with eDP + DP-1 (primary 4K) + HDMI-A-2 (rotated portrait).

local apps = require("lua.apps")
local edp = "eDP-1"
local horizontal = "desc:LG Electronics LG HDR 4K 0x0007807F"
local vertical = "desc:LG Electronics LG HDR 4K 0x0007FDE4"
-- ── Monitors ────────────────────────────────────────────────────────────────
hl.monitor({ output = edp,    mode = "2560x1600@240", position = "187x1296",  scale = 1.33 })
hl.monitor({ output = horizontal,     mode = "3840x2160@60",  position = "0x0",       scale = 1.67 })
hl.monitor({ output = vertical, mode = "3840x2160@60",  position = "2304x-620", scale = 1.67, transform = 3 })

-- ── Per-host workspace assignments (override lua/monitors.lua defaults) ─────
local dp1 = horizontal
hl.workspace_rule({ workspace = "1", monitor = dp1, default = true, persistent = true })
hl.workspace_rule({ workspace = "2", monitor = dp1, persistent = true })
hl.workspace_rule({ workspace = "3", monitor = dp1, persistent = true })
hl.workspace_rule({ workspace = "4", monitor = dp1, persistent = true })
hl.workspace_rule({ workspace = "5", monitor = dp1, persistent = true })

local hdmi = vertical
hl.workspace_rule({ workspace = "6", monitor = hdmi, default = true, persistent = true })
hl.workspace_rule({ workspace = "7", monitor = hdmi, persistent = true })
hl.workspace_rule({ workspace = "8", monitor = hdmi, persistent = true })

hl.workspace_rule({ workspace = "9",  monitor = edp, default = true, persistent = true })
hl.workspace_rule({ workspace = "10", monitor = edp, persistent = true })
hl.workspace_rule({ workspace = "11", monitor = edp, persistent = true })
hl.workspace_rule({ workspace = "12", monitor = edp, persistent = true })

-- Note: the old config had `workspace = m[HDMI-A-2], layoutopt:orientation:top`
-- for master-layout portrait orientation, but `layoutopt:*` is not a valid
-- field on hl.workspace_rule and the global layout is dwindle anyway, so this
-- was effectively dead. Re-add via the master layout API if needed.

-- ── Autostart ───────────────────────────────────────────────────────────────
hl.on("hyprland.start", function()
  hl.exec_cmd("/usr/bin/rog-control-center")
  hl.exec_cmd("/usr/bin/kdeconnect-indicator")
end)

-- ── Host-specific binds ─────────────────────────────────────────────────────
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(apps.rog_brightness_up),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(apps.rog_brightness_down), { locked = true, repeating = true })
hl.bind("XF86KbdBrightnessUp",   hl.dsp.exec_cmd("asusctl leds next"))
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("asusctl leds prev"))
