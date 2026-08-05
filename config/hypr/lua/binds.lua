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
hl.bind(MS .. " + D",      dsp.exec_cmd("discord --enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform=wayland")) -- Discord
hl.bind(MS .. " + A",      dsp.exec_cmd("/home/ali/Games/audiorelay-0.27.5/bin/AudioRelay")) -- AudioRelay

-- ▸ Menus & overlays
hl.bind(M  .. " + D",     dsp.exec_cmd(apps.menu))       -- app launcher
hl.bind(MS .. " + W",     dsp.exec_cmd(apps.wmenu))      -- window switcher
hl.bind(M  .. " + Tab",   dsp.exec_cmd(apps.overview))   -- overview
-- Physical Alt+Tab: Toshy's modmaps leave Alt untouched and its Cmd-Tab
-- keymaps are commented out, so this reaches Hyprland as plain ALT — and it's
-- the macOS Cmd+Tab position, which fits an overview/switcher.
hl.bind("ALT + Tab",      dsp.exec_cmd(apps.overview))   -- overview (physical Alt)
hl.bind(MS .. " + V",     dsp.exec_cmd(apps.clipboard))  -- clipboard history
hl.bind(MS .. " + P",     dsp.exec_cmd(apps.colorpicker))-- color picker
hl.bind(MS .. " + C",     dsp.exec_cmd(apps.bar))        -- toggle bar
hl.bind(M  .. " + slash", dsp.exec_cmd(apps.keycheat))   -- shortcuts cheatsheet
hl.bind(M  .. " + N",     dsp.exec_cmd("qs ipc -c qshell call popouts toggle notifs")) -- notification center

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
local ws_keys = {
  [1] = "1", [2] = "2", [3] = "3", [4] = "4",  [5] = "5",
  [6] = "F1", [7] = "F2", [8] = "F3", [9] = "F4", [10] = "F5", [11] = "F6", [12] = "F7",
}
for ws, key in pairs(ws_keys) do
  hl.bind(M  .. " + " .. key, dsp.focus({ workspace = ws }))                       -- switch workspace 1-12
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
hl.bind(MS .. " + M", dsp.exec_cmd(apps.toggle_edp))        -- toggle eDP
hl.bind(MS .. " + O", dsp.exec_cmd(apps.relight_displays))  -- relight stuck/blank display (panic)
hl.bind(MS .. " + N", dsp.exec_cmd(apps.toggle_edp_refresh))-- toggle refresh rate
hl.bind(MS .. " + n", dsp.exec_cmd(apps.toggle_edp_refresh))
hl.bind(MC .. " + M", dsp.exec_cmd("/home/ali/labs/dotfiles/bin/hypr-monitor-manager.sh auto"))          -- monitors: auto
hl.bind(MC .. " + E", dsp.exec_cmd("/home/ali/labs/dotfiles/bin/hypr-monitor-manager.sh setup-external"))-- monitors: external
hl.bind(MC .. " + L", dsp.exec_cmd("/home/ali/labs/dotfiles/bin/hypr-monitor-manager.sh setup-laptop"))  -- monitors: laptop
hl.bind(MC .. " + D", dsp.exec_cmd("hyprctl keyword xwayland:force_zero_scaling = true"))  -- xwayland scaling on
hl.bind(MC .. " + S", dsp.exec_cmd("hyprctl keyword xwayland:force_zero_scaling = false")) -- xwayland scaling off

-- ▸ Shell toggles
hl.bind(MC .. " + P", dsp.exec_cmd(apps.power_profile))  -- cycle power profile (OSD confirms)
hl.bind(MC .. " + N", dsp.exec_cmd(apps.dnd))            -- do not disturb toggle

-- ▸ Mouse
hl.bind(M .. " + mouse:272", dsp.window.drag(),   { mouse = true }) -- drag to move
hl.bind(M .. " + mouse:273", dsp.window.resize(), { mouse = true }) -- drag to resize
hl.bind(M .. " + mouse_down",  -- scroll: zoom in
  dsp.exec_cmd([[hyprctl -q keyword cursor:zoom_factor $(hyprctl getoption cursor:zoom_factor -j | jq '.float * 1.1')]]))
hl.bind(M .. " + mouse_up",    -- scroll: zoom out
  dsp.exec_cmd([[hyprctl -q keyword cursor:zoom_factor $(hyprctl getoption cursor:zoom_factor -j | jq '(.float * 0.9) | if . < 1 then 1 else . end')]]))

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

-- ▸ Gestures (touchpad)
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
-- NOTE: a "2-finger swipe from touchpad edge → notifications" gesture is not
-- feasible: libinput reports 2-finger contact as scroll (no edge origin), and
-- hl.gesture only supports built-in actions (workspace/fullscreen/special/…),
-- not exec. Super+N toggles the notification center instead.
hl.gesture({ fingers = 4, direction = "swipe",      action = "move" })
