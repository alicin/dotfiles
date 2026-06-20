-- Keybinds, mouse binds, and gestures.
-- See https://wiki.hypr.land/Configuring/Basics/Binds/
--     https://wiki.hypr.land/Configuring/Basics/Dispatchers/

local apps = require("lua.apps")

local mod  = "SUPER"
local mod2 = "ALT"

-- Convenience: pre-built modifier combos that match the original conf naming.
local M       = mod
local MS      = mod .. " + SHIFT"
local MC      = mod .. " + CTRL"
local MA      = mod .. " + " .. mod2
local M2      = mod2
local M2S     = mod2 .. " + SHIFT"
local C       = "CTRL"
local CS      = "CTRL + SHIFT"
local CA      = "CTRL + " .. mod2

local dsp = hl.dsp

-- ── Bar ──────────────────────────────────────────────────────────────────────
hl.bind(MS .. " + C", dsp.exec_cmd(apps.bar))

-- ── Laptop multimedia keys ───────────────────────────────────────────────────
-- bindle (locked + repeat).
hl.bind("XF86AudioRaiseVolume", dsp.exec_cmd(apps.volume_up),   { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", dsp.exec_cmd(apps.volume_down), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        dsp.exec_cmd(apps.volume_mute), { locked = true, repeating = true })
-- bindl (locked, no repeat).
hl.bind("XF86AudioPlay",    dsp.exec_cmd("playerctl play"),     { locked = true })
hl.bind("XF86AudioStop",    dsp.exec_cmd("playerctl stop"),     { locked = true })
hl.bind("XF86AudioPause",   dsp.exec_cmd("playerctl pause"),    { locked = true })
hl.bind("XF86AudioPrev",    dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86AudioNext",    dsp.exec_cmd("playerctl next"),     { locked = true })
hl.bind("XF86AudioMicMute", dsp.exec_cmd(apps.mic_mute),        { locked = true })

-- ── Runtime scaling toggle ───────────────────────────────────────────────────
hl.bind(M2S .. " + D", dsp.exec_cmd("hyprctl keyword xwayland:force_zero_scaling = true"))
hl.bind(M2S .. " + S", dsp.exec_cmd("hyprctl keyword xwayland:force_zero_scaling = false"))

-- ── Screenshot / record / monitor toggle ─────────────────────────────────────
hl.bind(MS .. " + S", dsp.exec_cmd(apps.grab))
hl.bind(MS .. " + R", dsp.exec_cmd(apps.record))
-- macOS-style: Cmd+Shift+4 area screenshot, Cmd+Shift+5 toggle area recording.
-- Cmd = physical Alt, which Toshy re-emits as Ctrl.
hl.bind(CS .. " + 4", dsp.exec_cmd(apps.screenshot_area))
hl.bind(CS .. " + 5", dsp.exec_cmd(apps.record_toggle))
hl.bind(MS .. " + M", dsp.exec_cmd(apps.toggle_edp))
hl.bind(MS .. " + N", dsp.exec_cmd(apps.toggle_edp_refresh))
hl.bind(MS .. " + n", dsp.exec_cmd(apps.toggle_edp_refresh))

-- ── Launchers ────────────────────────────────────────────────────────────────
hl.bind(M  .. " + Return",  dsp.exec_cmd(apps.term))
hl.bind(M  .. " + W",       dsp.exec_cmd(apps.browser))
hl.bind(M  .. " + E",       dsp.exec_cmd(apps.filemanager))
hl.bind(MS .. " + Return",  dsp.exec_cmd(apps.term_float))
hl.bind(MA .. " + Return",  dsp.exec_cmd(apps.term_float_portrait))
hl.bind(M2S .. " + Return", dsp.exec_cmd(apps.editor .. " --enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform=wayland"))
hl.bind(MS .. " + D",       dsp.exec_cmd("discord --enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform=wayland"))
-- Clipboard history. Under Toshy, physical Cmd (the Alt key) is re-emitted as
-- Right Control, so "Cmd + Shift + V" reaches Hyprland as CTRL + SHIFT + V.
-- Physical Super is remapped away entirely, so MS (SUPER+SHIFT) never matches.
hl.bind(CS .. " + V", dsp.exec_cmd(apps.clipboard))
-- Colorpicker on physical Cmd+Shift+P (Cmd = Alt -> Ctrl under Toshy).
hl.bind(CS .. " + P", dsp.exec_cmd(apps.colorpicker))
-- Original had `$modR, d` — `$modR` is an undefined variable in the old config
-- and almost certainly a typo for `$mod`. Translating as plain mod here.
hl.bind(M  .. " + D",       dsp.exec_cmd(apps.menu))
hl.bind(MS .. " + W",       dsp.exec_cmd(apps.wmenu))
hl.bind(M  .. " + Tab",     dsp.exec_cmd(apps.overview))

-- ── Window / session ─────────────────────────────────────────────────────────
hl.bind(CA .. " + Delete", dsp.exit())
hl.bind(M  .. " + Q",      dsp.window.close())              -- also Cmd+Q: Toshy maps Cmd+Q -> Super+Q (see user_apps slice in toshy_config.py). Avoids the Alt+F4 clash with workspace 9.
hl.bind(MS .. " + Q",      dsp.window.kill())              -- was forcekillactive
hl.bind(M  .. " + Space",  dsp.window.float({ action = "toggle" }))
hl.bind(M  .. " + F",      dsp.window.fullscreen({ action = "toggle" }))
hl.bind(MS .. " + F",      dsp.window.fullscreen({ action = "toggle" }))  -- duplicate kept for parity
-- macOS-style: Cmd+F fullscreen, Cmd+Shift+F float toggle (Cmd = physical Alt -> Ctrl).
hl.bind(C  .. " + F",      dsp.window.fullscreen({ action = "toggle" }))
hl.bind(CS .. " + F",      dsp.window.float({ action = "toggle" }))
hl.bind(M  .. " + P",      dsp.layout("togglesplit"))

-- ── Focus ────────────────────────────────────────────────────────────────────
hl.bind(M .. " + left",  dsp.focus({ direction = "l" }))
hl.bind(M .. " + right", dsp.focus({ direction = "r" }))
hl.bind(M .. " + up",    dsp.focus({ direction = "u" }))
hl.bind(M .. " + down",  dsp.focus({ direction = "d" }))

-- ── Move window in tile layout ───────────────────────────────────────────────
hl.bind(MS .. " + left",  dsp.window.move({ direction = "l" }))
hl.bind(MS .. " + right", dsp.window.move({ direction = "r" }))
hl.bind(MS .. " + up",    dsp.window.move({ direction = "u" }))
hl.bind(MS .. " + down",  dsp.window.move({ direction = "d" }))

-- ── Cycle workspaces ─────────────────────────────────────────────────────────
hl.bind(MC .. " + left",  dsp.focus({ workspace = "e-1" }))
hl.bind(MC .. " + right", dsp.focus({ workspace = "e+1" }))

-- ── Switch to / move to workspace 1..12 ──────────────────────────────────────
-- Workspaces 1-5 use digit keys; 6-12 use F1-F7.
local ws_keys = {
  [1] = "1", [2] = "2", [3] = "3", [4] = "4",  [5] = "5",
  [6] = "F1", [7] = "F2", [8] = "F3", [9] = "F4", [10] = "F5", [11] = "F6", [12] = "F7",
}
-- NOTE: Under Toshy the physical Super/Win key is re-emitted as ALT (it is the
-- macOS "Option" key in Toshy's layout), so to switch/move with the physical
-- Super key these bind to ALT / ALT+SHIFT, not SUPER. See the toshy-hypr-bind
-- skill for the full physical->emitted modifier map.
for ws, key in pairs(ws_keys) do
  hl.bind(M2  .. " + " .. key,         dsp.focus({ workspace = ws }))
  hl.bind(M2S   .. " + " .. key,         dsp.window.move({ workspace = ws, follow = false }))
end

-- ── Special workspaces ───────────────────────────────────────────────────────
-- Unnamed default special workspace.
hl.bind(M  .. " + grave", dsp.workspace.toggle_special(""))
hl.bind(MS .. " + grave", dsp.window.move({ workspace = "special", follow = false }))
-- Named "void" special workspace.
hl.bind(M  .. " + 0",     dsp.workspace.toggle_special("void"))
hl.bind(MS .. " + 0",     dsp.window.move({ workspace = "special:void", follow = false }))

-- ── Resize / move active window with hjkl (binde: repeats while held) ────────
hl.bind(MC .. " + k", dsp.window.resize({ x = 0,  y = -20, relative = true }), { repeating = true })
hl.bind(MC .. " + j", dsp.window.resize({ x = 0,  y = 20,  relative = true }), { repeating = true })
hl.bind(MC .. " + l", dsp.window.resize({ x = 20, y = 0,   relative = true }), { repeating = true })
hl.bind(MC .. " + h", dsp.window.resize({ x = -20, y = 0,  relative = true }), { repeating = true })

hl.bind(MA .. " + k", dsp.window.move({ x = 0,  y = -20, relative = true }), { repeating = true })
hl.bind(MA .. " + j", dsp.window.move({ x = 0,  y = 20,  relative = true }), { repeating = true })
hl.bind(MA .. " + l", dsp.window.move({ x = 20, y = 0,   relative = true }), { repeating = true })
hl.bind(MA .. " + h", dsp.window.move({ x = -20, y = 0,  relative = true }), { repeating = true })

-- ── Mouse: drag / resize floating windows ────────────────────────────────────
-- Physical Super + drag. Toshy re-emits physical Super as ALT, so these bind to
-- ALT, not SUPER (which never reaches Hyprland from the physical Super key).
hl.bind(mod2 .. " + mouse:272", dsp.window.drag(),   { mouse = true })
hl.bind(mod2 .. " + mouse:273", dsp.window.resize(), { mouse = true })

-- ── Gestures ─────────────────────────────────────────────────────────────────
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 4, direction = "swipe",      action = "move" })

-- ── Zoom (scroll + mod) ──────────────────────────────────────────────────────
-- Bumps cursor:zoom_factor by ±10% per scroll tick via hyprctl.
hl.bind(M .. " + mouse_down",
  dsp.exec_cmd([[hyprctl -q keyword cursor:zoom_factor $(hyprctl getoption cursor:zoom_factor -j | jq '.float * 1.1')]]))
hl.bind(M .. " + mouse_up",
  dsp.exec_cmd([[hyprctl -q keyword cursor:zoom_factor $(hyprctl getoption cursor:zoom_factor -j | jq '(.float * 0.9) | if . < 1 then 1 else . end')]]))

-- ── Monitor management ───────────────────────────────────────────────────────
hl.bind(M2S .. " + M", dsp.exec_cmd("/home/ali/labs/dotfiles/bin/hypr-monitor-manager.sh auto"))
hl.bind(M2S .. " + E", dsp.exec_cmd("/home/ali/labs/dotfiles/bin/hypr-monitor-manager.sh setup-external"))
hl.bind(M2S .. " + L", dsp.exec_cmd("/home/ali/labs/dotfiles/bin/hypr-monitor-manager.sh setup-laptop"))

-- ── Misc ─────────────────────────────────────────────────────────────────────
hl.bind(MS .. " + A", dsp.exec_cmd("/home/ali/Games/audiorelay-0.27.5/bin/AudioRelay"))
