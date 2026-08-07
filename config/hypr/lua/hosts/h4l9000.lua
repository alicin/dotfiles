-- h4l9000 — laptop with eDP + DP-1 (primary 4K) + HDMI-A-2 (rotated portrait).

local apps = require("lua.apps")
local edp = "eDP-1"

-- ── GPU device pin (compositor) ─────────────────────────────────────────────
-- Hybrid Intel+nvidia box, so the compositor has to be told which card to use.
-- Only a fallback for a bare `--cmd Hyprland` launch that bypasses uwsm --
-- correct for the Integrated/Hybrid desktop modes; in AsusMuxDgpu (MUX) mode
-- use the uwsm session, whose ~/.config/uwsm/env is supergfx-mode-aware.
--
-- AQ_DRM_DEVICES is ':'-delimited, so the value must NOT contain colons. A raw
-- by-path name (pci-0000:00:02.0-card) is split on its own colons into garbage
-- -> "Found no gpus" -> crash loop. The colon-free ~/.config/hypr/igpu symlink
-- chains through the udev by-path link, and survives card0/card1 renumbering.
hl.env("AQ_DRM_DEVICES", "/home/ali/.config/hypr/igpu")
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

-- ── Looking Glass (win11 passthrough VM) ────────────────────────────────────
-- Moved here from lua/options.lua + lua/rules.lua, where all three applied to
-- every host: only this machine has the LG client (profiles/h4l9000-arch), and
-- vfr=false is a real battery/heat cost elsewhere -- k3v1n was compositing
-- every idle frame at 120Hz for a VM it cannot run. Hosts load last, so these
-- override the shared defaults.
hl.config({
  general = {
    -- Let the fullscreen LG client tear (present without waiting for vblank);
    -- required for its `egl:vsync=no` to actually skip the compositor's frame
    -- queue -- without it LG frames queue to vblank and the guest stutters.
    allow_tearing = true,
  },
  debug = {
    -- VFR throttles the render loop when the screen looks idle, which starves
    -- LG's frame pacing -> guest video collapses to a few FPS while the mouse
    -- is still. Cost: full-rate compositing when idle, on this host only.
    -- (If that ever matters here too, the LG launch script can toggle it
    -- per-session with `hyprctl -r eval 'hl.config({ debug = { vfr = … } })'`
    -- -- runtime eval works; an older comment claiming otherwise is why this
    -- sat in the global options for so long.)
    vfr = false,
  },
})
hl.window_rule({ match = { class = "^(looking-glass-client)$" }, immediate = true })

-- ── Autostart ───────────────────────────────────────────────────────────────
hl.on("hyprland.start", function()
  hl.exec_cmd("/usr/bin/rog-control-center")
end)

-- ── Host-specific binds ─────────────────────────────────────────────────────
-- Workspaces 10-12: lua/binds.lua covers 1-9 for every host (k3v1n's count);
-- this machine runs twelve, so the top three live here.
for ws, key in pairs({ [10] = "F5", [11] = "F6", [12] = "F7" }) do
  hl.bind("SUPER + " .. key,           hl.dsp.focus({ workspace = ws }))
  hl.bind("SUPER + SHIFT + " .. key,   hl.dsp.window.move({ workspace = ws, follow = false }))
end

hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(apps.rog_brightness_up),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(apps.rog_brightness_down), { locked = true, repeating = true })

-- Apps only this machine has (moved out of lua/binds.lua, where they were
-- dead keys on the other two hosts).
hl.bind("SUPER + SHIFT + D", hl.dsp.exec_cmd("discord --enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform=wayland")) -- Discord
hl.bind("SUPER + SHIFT + A", hl.dsp.exec_cmd("/home/ali/Games/audiorelay-0.27.5/bin/AudioRelay")) -- AudioRelay
-- No XF86KbdBrightnessUp/Down binds here on purpose. This laptop's keyboard
-- backlight key never reaches the compositor: no input device declares
-- KEY_KBDILLUMUP at all (the Asus WMI hotkeys device exposes volume, mic-mute
-- and display brightness, and nothing for the keyboard light), so a bind on it
-- is dead config — which is why the old `asusctl leds next` binding here never
-- did anything either. asusd owns that key, and qshell watches asusd's
-- xyz.ljones.Aura.Brightness over DBus to draw the OSD (services/Brightness.qml).
