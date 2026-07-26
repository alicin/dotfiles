-- h4l9000 — laptop with eDP + DP-1 (primary 4K) + HDMI-A-2 (rotated portrait).

local apps = require("lua.apps")
local edp = "eDP-1"
local horizontal = "desc:LG Electronics LG HDR 4K 0x0007807F"
local vertical = "desc:LG Electronics LG HDR 4K 0x0007FDE4"
-- ── Monitors ────────────────────────────────────────────────────────────────
hl.monitor({ output = edp,    mode = "2560x1600@240", position = "187x1296",  scale = 1.33333333 })
hl.monitor({ output = horizontal,     mode = "3840x2160@60",  position = "0x0",       scale = 1.666667 })
hl.monitor({ output = vertical, mode = "3840x2160@60",  position = "2304x-620", scale = 1.333333, transform = 3 })

-- ── Per-host workspace assignments (override lua/monitors.lua defaults) ─────
-- Dock-aware. The 3-finger workspace swipe (see lua/binds.lua) only visits
-- workspaces that currently *exist*, and a workspace "exists" only if it is
-- persistent or holds a window. A persistent rule bound to an *absent* monitor
-- is never created, so we split by dock state:
--   • docked  -> each monitor owns its slice (1-5 DP, 6-8 HDMI, 9-12 laptop)
--   • laptop  -> ALL 12 are persistent on eDP, so the swipe cycles every one
-- Re-evaluation on plug/unplug is handled by the reload hook further down.
local dp1  = horizontal
local hdmi = vertical

local function ws(id, monitor, default)
  hl.workspace_rule({ workspace = tostring(id), monitor = monitor, persistent = true, default = default })
end

-- True when any monitor other than the built-in laptop panel is connected.
local function externals_connected()
  for _, m in ipairs(hl.get_monitors()) do
    if m.name ~= edp then return true end
  end
  return false
end

local docked = externals_connected()
if docked then
  ws(1, dp1, true); ws(2, dp1); ws(3, dp1); ws(4, dp1); ws(5, dp1)
  ws(6, hdmi, true); ws(7, hdmi); ws(8, hdmi)
  ws(9, edp, true); ws(10, edp); ws(11, edp); ws(12, edp)
else
  for i = 1, 12 do ws(i, edp, i == 1) end
end

-- Follow the dock state when a monitor is plugged in / unplugged: re-run this
-- file via a config reload so the workspace layout above is recomputed. Gated
-- on an actual docked<->undocked transition so it never storms (Hyprland's Lua
-- runtime clears event subscriptions on reload, so these don't accumulate).
_G.__h4l_docked = docked
local function follow_dock_state()
  if externals_connected() ~= _G.__h4l_docked then
    hl.exec_cmd("hyprctl reload")
  end
end
hl.on("monitor.added",   follow_dock_state)
hl.on("monitor.removed", follow_dock_state)

-- Note: the old config had `workspace = m[HDMI-A-2], layoutopt:orientation:top`
-- for master-layout portrait orientation, but `layoutopt:*` is not a valid
-- field on hl.workspace_rule and the global layout is dwindle anyway, so this
-- was effectively dead. Re-add via the master layout API if needed.

-- ── Autostart ───────────────────────────────────────────────────────────────
hl.on("hyprland.start", function()
  hl.exec_cmd("/usr/bin/rog-control-center")
end)

-- ── Host-specific binds ─────────────────────────────────────────────────────
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(apps.rog_brightness_up),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(apps.rog_brightness_down), { locked = true, repeating = true })
hl.bind("XF86KbdBrightnessUp",   hl.dsp.exec_cmd(apps.kb_brightness_up))
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd(apps.kb_brightness_down))
