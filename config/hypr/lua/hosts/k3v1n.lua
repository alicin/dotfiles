-- k3v1n — tablet with eDP + occasional external LG 4K displays.

local apps = require("lua.apps")

-- ── Monitors ────────────────────────────────────────────────────────────────
-- 166% (5/3) rather than 133%: this is a 14" panel held at arm's length and
-- tapped with a finger, not a laptop screen read from 50cm. Both axes divide
-- exactly at 3/5 -- 2560*3/5 = 1536, 1600*3/5 = 960 -- so Hyprland takes the
-- fraction as given instead of rejecting it or snapping to a neighbouring one,
-- which is why this is 1.666667 and not, say, 1.6 or 1.75.
--
-- qshell scales on top of this (Appearance.s()), and its touch mode multiplies
-- again, so the shell's own targets are sized against the 1536x960 logical
-- desktop this produces -- not the 1920x1200 it used to be.
hl.monitor({ output = "eDP-1", mode = "2560x1600@120", position = "0x0", scale = 1.666667 })
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

-- ── Per-host workspaces (dock-aware, the h4l9000 pattern) ───────────────────
-- Undocked: all nine on the panel. Docked to the LG pair: 1-5 on the
-- horizontal, 6-8 on the portrait, 9 stays home on the tablet — the spread
-- hypr-monitor-manager.sh used to do imperatively (and silently failed to, for
-- the whole Lua-config era) is these rules plus the reload hook below.
local edp        = "eDP-1"
local horizontal = "desc:LG Electronics LG HDR 4K 0x0007807F"
local vertical   = "desc:LG Electronics LG HDR 4K 0x0007FDE4"

local function ws(id, monitor, default)
  hl.workspace_rule({ workspace = tostring(id), monitor = monitor, persistent = true, default = default })
end

local function externals_connected()
  for _, m in ipairs(hl.get_monitors()) do
    if m.name ~= edp then return true end
  end
  return false
end

local docked = externals_connected()
if docked then
  ws(1, horizontal, true); ws(2, horizontal); ws(3, horizontal); ws(4, horizontal); ws(5, horizontal)
  ws(6, vertical, true); ws(7, vertical); ws(8, vertical)
  ws(9, edp, true)
else
  for i = 1, 9 do ws(i, edp, i == 1) end
end

-- Re-evaluate on plug/unplug via a config reload, gated on an actual
-- docked<->undocked transition so it never storms (the Lua runtime clears
-- event subscriptions on reload, so these don't accumulate).
_G.__k3v_docked = docked
local function follow_dock_state()
  if externals_connected() ~= _G.__k3v_docked then
    hl.exec_cmd("hyprctl reload")
  end
end
hl.on("monitor.added",   follow_dock_state)
hl.on("monitor.removed", follow_dock_state)

-- ── Autostart ───────────────────────────────────────────────────────────────
-- No squeekboard. It used to be launched here as the on-screen keyboard, but it
-- puts a keyboard on screen in a normal desktop session -- not wanted even on a
-- convertible. The other half of that feature (scripts/osk.sh, which installed a
-- udev rule flipping GNOME's a11y screen-keyboard on whenever a keyboard was
-- unplugged) is gone from this profile's post_install for the same reason.
hl.on("hyprland.start", function()
  hl.exec_cmd("corectrl --minimize-systray")
  -- The touchscreen->touchpad bridge: grabs the digitiser and replays
  -- 3/4-finger contact sets onto a virtual touchpad, so lua/binds.lua's
  -- hl.gesture() bindings drive touchscreen fingers through the very same
  -- compositor gesture code the physical trackpad uses (Hyprland 0.56 has no
  -- touchscreen gesture system of its own -- see the header in the script).
  -- Ordinary 1-2 finger touches pass through a touchscreen clone unchanged.
  -- Host autostart rather than lua/startup.lua because this is the only
  -- machine with a touchscreen.
  hl.exec_cmd("/home/ali/labs/dotfiles/bin/touch-gestures")
end)

-- ── Host-specific binds ─────────────────────────────────────────────────────
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(apps.brightness_up),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(apps.brightness_down), { locked = true, repeating = true })
-- No keyboard-backlight binds: this chassis has no keyboard LED at all, and
-- the old Super+z pair fell back to asusctl — an ASUS ROG tool that has no
-- business on a Minisforum.

-- ── Tablet binds (see todo-tablet.md) ───────────────────────────────────────
-- Only on this host: the other two machines have no touchscreen, and these
-- would be three keybinds that do nothing there. Super+Ctrl is the group with
-- room left in it -- O, T and R are all unclaimed in lua/binds.lua.
--
-- Not in lua/binds.lua and therefore not in the Super+/ cheatsheet, which only
-- parses that file. Same trade the brightness binds above already make.
hl.bind("SUPER + CTRL + O", hl.dsp.exec_cmd("qs -c qshell ipc call osk toggle"))     -- on-screen keyboard
hl.bind("SUPER + CTRL + T", hl.dsp.exec_cmd("qs -c qshell ipc call tablet toggle"))  -- force tablet/auto mode
hl.bind("SUPER + CTRL + R", hl.dsp.exec_cmd("qs -c qshell ipc call display rotate")) -- rotate the panel 90°

-- ── Touch input ─────────────────────────────────────────────────────────────
-- The digitiser reports touch and stylus as one device (PNP0C50:00 222A:550D).
-- `input:touchdevice:output = eDP-1` (lua/options.lua) pins it to the panel --
-- which selects WHICH monitor box the coordinates land in, and nothing more.
-- Rotation is NOT automatic: Hyprland 0.56 never applies the output transform
-- to touch or stylus coordinates (verified in Touch.cpp; an earlier comment
-- here claimed the pinning handled it, and taps landed sideways on a rotated
-- panel). When qshell rotates the panel, services/Displays.qml also writes
-- input:touchdevice:transform + input:tablet:transform via `hyprctl -r eval`
-- (runtime hl.config writes re-apply the libinput calibration matrices), and
-- bin/touch-gestures counter-rotates its gesture pads itself -- they are
-- pointer devices, outside the calibration path -- by watching wl_output.
--
-- The 3/4-finger gestures in lua/binds.lua reach the touchscreen through that
-- same bridge (see the autostart note above): contact sets are replayed onto
-- virtual touchpads, so the compositor's own trackpad gesture engine drives
-- them. Their speed is calibrated per-device in lua/devices.lua.
-- `gestures:workspace_swipe_touch` (lua/options.lua) is NOT dead, despite what
-- an earlier review concluded: in 0.56 it is a native 1-finger workspace swipe
-- that must START within gaps_out+border (~16 logical px) of the screen edge
-- (Touch.cpp onTouchDown; the injection test that called it dead started
-- mid-screen). In touch mode qshell's edge strips sit on those edges on a
-- higher layer and win; where the strips are absent (docked), the native edge
-- swipe still works. qshell's strips (modules/gestures/EdgeSwipes.qml) cover
-- the launcher/overview/control-center edges.
