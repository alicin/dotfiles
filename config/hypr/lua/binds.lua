-- Hyprland keybinds, mouse binds, gestures.  https://wiki.hypr.land/Configuring/Basics/Binds/
--
-- Modifier scheme (Toshy active): physical Alt = macOS Command (Toshy owns it), so every
-- WM bind lives on the physical Super key. Super/Ctrl stay native. Trailing "-- label"
-- comments double as the data for the shortcuts overlay (Super+/ or Alt+Shift+?).

local apps = require("lua.apps")
local dsp  = hl.dsp

local mod = "SUPER"
local M   = mod                        -- Super
local MS  = mod .. " + SHIFT"          -- Super + Shift
local MC  = mod .. " + CTRL"           -- Super + Ctrl
local MCS = mod .. " + CTRL + SHIFT"   -- Super + Ctrl + Shift

-- ▸ Launchers
hl.bind(MS .. " + backslash", dsp.exec_cmd(apps.term))        -- terminal  (Super+Enter is now macOS Option+Enter, via Toshy)
hl.bind(MS .. " + Return", dsp.exec_cmd(apps.term_float))     -- floating terminal
hl.bind(MC .. " + Return", dsp.exec_cmd(apps.term_float_portrait)) -- portrait terminal
hl.bind(M  .. " + W",      dsp.exec_cmd(apps.browser))        -- browser
hl.bind(M  .. " + E",      dsp.exec_cmd(apps.filemanager))    -- file manager
hl.bind(M  .. " + C",      dsp.exec_cmd(apps.editor .. " --enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform=wayland")) -- editor / VS Code
-- Discord and AudioRelay moved to hosts/h4l9000.lua — neither is installed
-- on k3v1n or mcu, and a global bind to an absent app is a dead key.

-- ▸ Menus & overlays
hl.bind(M  .. " + D",     dsp.exec_cmd(apps.menu))       -- app launcher
hl.bind(MS .. " + W",     dsp.exec_cmd(apps.wmenu))      -- window switcher
hl.bind(M  .. " + Tab",   dsp.exec_cmd(apps.overview))   -- overview
-- Physical Alt+Tab reaches this bind BECAUSE of Toshy, not despite it: the
-- modmaps turn physical Alt into Cmd (both contexts), and General GUI's
-- active `C("RC-Tab") -> Alt-Tab` keymap is what re-emits the Alt+Tab this
-- binds on. Do not "simplify" that entry away in toshy_config.py — this bind
-- dies with it. (An older comment here claimed the exact opposite on both
-- counts.) It's the macOS Cmd+Tab position, which fits an overview/switcher;
-- physical Right-Win+Tab — the one input-side Alt — lands here too.
hl.bind("ALT + Tab",      dsp.exec_cmd(apps.overview))   -- overview (physical Alt)
hl.bind(MS .. " + V",     dsp.exec_cmd(apps.clipboard))  -- clipboard history
-- Both open the same launcher panel, straight into a prefix mode; the mode is
-- typeable too (> and :), so these are shortcuts, not the only way in.
hl.bind(MC .. " + Space", dsp.exec_cmd(apps.cmenu))      -- command palette
hl.bind(M  .. " + period", dsp.exec_cmd(apps.emoji))     -- emoji picker
hl.bind(MS .. " + P",     dsp.exec_cmd(apps.colorpicker))-- color picker
hl.bind(MS .. " + C",     dsp.exec_cmd(apps.bar))        -- toggle bar
hl.bind(M  .. " + slash", dsp.exec_cmd(apps.keycheat))   -- shortcuts cheatsheet
hl.bind(M  .. " + N",     dsp.exec_cmd("qs ipc -c qshell call popouts toggle notifs")) -- notification center
-- Picture-in-Picture. On MS+I rather than M+I because Toshy's stock IDE keymap
-- maps bare Super-i to Ctrl+I ("Implement methods") *below* the user_apps
-- slice, so M+I would be eaten in those apps and work everywhere else — which
-- is worse than not existing. Super+Shift+I is clear on both sides.
hl.bind(MS .. " + I",     dsp.exec_cmd(apps.pip))        -- picture-in-picture (focused window)
hl.bind(MCS .. " + I",    dsp.exec_cmd(apps.pip_corner)) -- move picture-in-picture corner
-- Comma for the settings-ish panel, the one convention every desktop shares.
-- The submap entry lives here rather than in submaps/control.lua so the
-- cheatsheet — which only parses this file — can see it; the submap's own
-- definition is over there with the power one.
hl.bind(M  .. " + comma", dsp.exec_cmd(apps.control))    -- control center
hl.bind(MS .. " + comma", dsp.submap("control"),         -- control center pages: (s)ound (b)luetooth (k)de connect (d)isplays
  { description = "Control Center pages: (s)ound (b)luetooth (k)de connect (d)isplays (c)ontrol" })
-- Entry bind here, definition in submaps/power.lua — same cheatsheet trade as
-- the control submap above: this is the submap where a wrong guess reboots.
hl.bind(MS .. " + E", dsp.submap("power"),               -- power: (l)ock (e)xit (r)eboot (p)oweroff (s)uspend
  { description = "Power submap: (l)ock (e)xit (r)eboot (p)oweroff (s)uspend" })

-- ▸ Window
hl.bind(M  .. " + Q",     dsp.window.close())                          -- close
hl.bind(MS .. " + Q",     dsp.window.kill())                           -- force kill
hl.bind(M  .. " + F",     dsp.window.fullscreen({ action = "toggle" }))-- fullscreen
hl.bind(MS .. " + F",     dsp.window.fullscreen({ action = "toggle" }))-- fullscreen
hl.bind(M  .. " + Space", dsp.window.float({ action = "toggle" }))     -- toggle float
hl.bind(M  .. " + P",     dsp.layout("togglesplit"))                   -- toggle split
hl.bind(MC .. " + Delete", dsp.exit())                                 -- exit session

-- ▸ Focus
-- Super+arrows are word-wise TEXT nav (Toshy), so window focus is on vim keys.
hl.bind(M .. " + h", dsp.focus({ direction = "l" }))  -- focus left
hl.bind(M .. " + j", dsp.focus({ direction = "d" }))  -- focus down
hl.bind(M .. " + k", dsp.focus({ direction = "u" }))  -- focus up
hl.bind(M .. " + l", dsp.focus({ direction = "r" }))  -- focus right

-- ▸ Move / resize / nudge
hl.bind(MS .. " + h", dsp.window.move({ direction = "l" }))  -- move left (tile)
hl.bind(MS .. " + j", dsp.window.move({ direction = "d" }))  -- move down (tile)
hl.bind(MS .. " + k", dsp.window.move({ direction = "u" }))  -- move up (tile)
hl.bind(MS .. " + l", dsp.window.move({ direction = "r" }))  -- move right (tile)
hl.bind(MC .. " + h", dsp.window.resize({ x = -20, y = 0,  relative = true }), { repeating = true }) -- resize narrower
hl.bind(MC .. " + j", dsp.window.resize({ x = 0,  y = 20,  relative = true }), { repeating = true }) -- resize taller
hl.bind(MC .. " + k", dsp.window.resize({ x = 0,  y = -20, relative = true }), { repeating = true }) -- resize shorter
hl.bind(MC .. " + l", dsp.window.resize({ x = 20, y = 0,   relative = true }), { repeating = true }) -- resize wider
hl.bind(MCS .. " + h", dsp.window.move({ x = -20, y = 0,  relative = true }), { repeating = true }) -- nudge left (float)
hl.bind(MCS .. " + j", dsp.window.move({ x = 0,  y = 20,  relative = true }), { repeating = true }) -- nudge down (float)
hl.bind(MCS .. " + k", dsp.window.move({ x = 0,  y = -20, relative = true }), { repeating = true }) -- nudge up (float)
hl.bind(MCS .. " + l", dsp.window.move({ x = 20, y = 0,   relative = true }), { repeating = true }) -- nudge right (float)

-- ▸ Workspaces
-- Nine here, for every host: k3v1n has nine (its host file pins 1-9 to the
-- panel and the shell shows nine). mcu's tenth and h4l9000's 10-12 are bound
-- in their own host files — a global F5-F7 would let a stray key on k3v1n
-- park a window on a workspace the bar and overview don't show.
local ws_keys = {
  [1] = "1", [2] = "2", [3] = "3", [4] = "4",  [5] = "5",
  [6] = "F1", [7] = "F2", [8] = "F3", [9] = "F4",
}
for ws, key in pairs(ws_keys) do
  hl.bind(M  .. " + " .. key, dsp.focus({ workspace = ws }))                       -- switch workspace 1-9
  hl.bind(MS .. " + " .. key, dsp.window.move({ workspace = ws, follow = false })) -- move window to workspace
end
hl.bind(M  .. " + grave", dsp.workspace.toggle_special(""))                          -- scratchpad
hl.bind(MS .. " + grave", dsp.window.move({ workspace = "special", follow = false }))-- move to scratchpad
hl.bind(M  .. " + 0",     dsp.workspace.toggle_special("void"))                      -- void scratchpad
hl.bind(MS .. " + 0",     dsp.window.move({ workspace = "special:void", follow = false })) -- move to void
hl.bind(MC .. " + left",  dsp.focus({ workspace = "e-1" }))  -- prev workspace
hl.bind(MC .. " + right", dsp.focus({ workspace = "e+1" }))  -- next workspace

-- ▸ Screen / display
-- macOS Cmd+Shift+4/5 style; physical Cmd (Left Alt) is emitted as Ctrl by Toshy.
hl.bind("CTRL + SHIFT + 4", dsp.exec_cmd(apps.grab))         -- area screenshot
hl.bind("CTRL + SHIFT + 5", dsp.exec_cmd(apps.record))       -- area screen record (toggle)
hl.bind("CTRL + SHIFT + 6", dsp.exec_cmd(apps.record_full))  -- full-screen record (toggle)
hl.bind("CTRL + SHIFT + 7", dsp.exec_cmd(apps.record_pause)) -- pause / resume recording
-- Continuing the capture family's digits rather than inventing a mnemonic:
-- Ctrl+Shift+T would have been the obvious one for "text" and is exactly what a
-- terminal emits for a new tab, which the Toshy terminal keymaps would eat first.
hl.bind("CTRL + SHIFT + 8", dsp.exec_cmd(apps.ocr))          -- copy text from a region (OCR)
hl.bind("CTRL + SHIFT + 9", dsp.exec_cmd(apps.qr_scan))      -- decode a QR code on screen
hl.bind(MS .. " + M", dsp.exec_cmd(apps.toggle_edp))        -- toggle eDP
hl.bind(MS .. " + O", dsp.exec_cmd(apps.relight_displays))  -- relight stuck/blank display (panic)
-- One registration only: Hyprland matches bind keys case-insensitively and
-- fires EVERY match, so an "N" and "n" pair here ran the toggle twice per
-- press — two racing script instances and a nondeterministic refresh rate.
hl.bind(MS .. " + N", dsp.exec_cmd(apps.toggle_edp_refresh))-- toggle refresh rate
-- Workspace-to-monitor layout is declarative now: per-host workspace RULES
-- (dock-aware on h4l9000 and k3v1n) recompute on config reload, and a
-- monitor.added/removed hook in those host files triggers the reload by
-- itself. hypr-monitor-manager.sh and its three keys are gone — this one key
-- remains as the manual nudge for the rare missed hotplug event.
hl.bind(MC .. " + M", dsp.exec_cmd("hyprctl reload"))  -- monitors: re-apply layout
-- In-process Lua: binds take functions, and a bind that only writes config
-- has no business spawning hyprctl (the eval form this replaces spawned one
-- per press; the `hyprctl keyword` form before it had NEVER worked — refused
-- under the Lua parser). Runtime hl.config() re-applies the option live.
hl.bind(MC .. " + D", function() hl.config({ xwayland = { force_zero_scaling = true } }) end)  -- xwayland scaling on
hl.bind(MC .. " + S", function() hl.config({ xwayland = { force_zero_scaling = false } }) end) -- xwayland scaling off

-- ▸ Shell toggles
hl.bind(MC .. " + P", dsp.exec_cmd(apps.power_profile))  -- cycle power profile (OSD confirms)
hl.bind(MC .. " + N", dsp.exec_cmd(apps.dnd))            -- do not disturb toggle

-- ▸ Mouse
hl.bind(M .. " + mouse:272", dsp.window.drag(),   { mouse = true }) -- drag to move
hl.bind(M .. " + mouse:273", dsp.window.resize(), { mouse = true }) -- drag to resize
-- Zoom, fully in-process (see the xwayland binds above for why lambdas, not
-- eval — this one used to spawn a process per SCROLL TICK).
hl.bind(M .. " + mouse_down", function() hl.config({ cursor = { zoom_factor = (hl.get_config("cursor.zoom_factor") or 1) * 1.1 } }) end)               -- scroll: zoom in
hl.bind(M .. " + mouse_up",   function() hl.config({ cursor = { zoom_factor = math.max(1, (hl.get_config("cursor.zoom_factor") or 1) * 0.9) } }) end)  -- scroll: zoom out

-- ▸ Media & hardware keys
hl.bind("XF86AudioRaiseVolume", dsp.exec_cmd(apps.volume_up),   { locked = true, repeating = true }) -- volume up
hl.bind("XF86AudioLowerVolume", dsp.exec_cmd(apps.volume_down), { locked = true, repeating = true }) -- volume down
hl.bind("XF86AudioMute",        dsp.exec_cmd(apps.volume_mute), { locked = true, repeating = true }) -- mute
hl.bind("XF86AudioMicMute",     dsp.exec_cmd(apps.mic_mute),        { locked = true }) -- mic mute
hl.bind("XF86AudioPlay",  dsp.exec_cmd("playerctl play"),     { locked = true }) -- play
hl.bind("XF86AudioStop",  dsp.exec_cmd("playerctl stop"),     { locked = true }) -- stop
hl.bind("XF86AudioPause", dsp.exec_cmd("playerctl pause"),    { locked = true }) -- pause
hl.bind("XF86AudioPrev",  dsp.exec_cmd("playerctl previous"), { locked = true }) -- previous
hl.bind("XF86AudioNext",  dsp.exec_cmd("playerctl next"),     { locked = true }) -- next

-- ▸ Gestures (touchpad — and, through the bridge, the touchscreen)
--
-- Hyprland 0.56's gesture system builds CTrackpadGesture objects: touchpad
-- only, no touchscreen equivalent (`mode = "touch"` parses but is inert —
-- verified by injection; the one native touchscreen gesture is
-- workspace_swipe_touch, a 1-finger swipe that must START within ~16px of a
-- screen edge — see hosts/k3v1n.lua). On k3v1n, bin/touch-gestures closes
-- the multi-finger gap from
-- the outside: it grabs the digitiser and replays 3/4-finger contact sets
-- onto a virtual TOUCHPAD, so every gesture below applies to touchscreen
-- fingers too — same compositor code, same 1:1 follow, same settings.
-- Edge swipes stay in the shell (qshell/modules/gestures/EdgeSwipes.qml).
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 4, direction = "swipe",      action = "move" })

-- Pinch to zoom: native cursorZoom (new in 0.56), live mode tracks the pinch
-- continuously and anchors at the cursor; zoom_level is unused in live mode.
-- Trackpad only by nature — the touchscreen bridge hands 2-finger input to
-- the apps on purpose (they own pinch there).
hl.gesture({ fingers = 2, direction = "pinch", action = "cursorZoom", zoom_level = 1, mode = "live" })

-- Three fingers up or down → overview. The macOS Mission Control gesture, in
-- the macOS position, on a config that is macOS-shaped everywhere else.
--
-- `action` does not have to be one of the built-in names: it also takes a table
-- of callbacks (start / update / end / finish), which is how a gesture reaches
-- something the compositor has no action for. An earlier note here claimed
-- hl.gesture "only supports built-in actions … not exec" and used that to rule
-- out a notifications gesture — the second half of that is simply wrong, and
-- this is the counter-example. (The first half stands: libinput reports
-- 2-finger contact as scroll with no edge origin, so an *edge* gesture is still
-- not expressible. Super+N remains the notification centre.)
--
-- Bound on `finish` rather than `update` so it fires once, at the end of the
-- swipe, instead of once per frame of it.
hl.gesture({
  fingers   = 3,
  direction = "vertical",
  action    = {
    finish = function() hl.exec_cmd(apps.overview) end,
  },
})
