-- Control Center submap: sound / bluetooth / KDE Connect / displays.
--
-- A submap rather than four more modifier combos. The panel's four pages are
-- siblings of one thing, and Super+Shift was down to `b e g i r s t u x y z`
-- with the obvious mnemonics (k, m, n, p, d, v, w) already spoken for — spread
-- across whatever was left they would have read as four unrelated shortcuts
-- rather than one group. They also aren't hot keys: the panel's home screen
-- carries the everyday controls, and these are the drill-downs.
--
-- The home screen keeps its own direct bind in binds.lua, because *that* one is
-- pressed often enough that a second keystroke would be felt.
--
-- Entering announces itself: qshell watches Hyprland's `submap` event and
-- raises the OSD hint in services/Osd.qml (submapHints), so the key list is on
-- screen the whole time this is active. Keep the two in sync — the event
-- carries only the submap's name, never its description.
--
-- Second arg "reset" auto-returns to the global submap after any dispatch, so
-- each binding is one line and can't strand the keyboard.

local apps = require("lua.apps")

hl.define_submap("control", "reset", function()
  hl.bind("s", hl.dsp.exec_cmd(apps.control_audio))
  hl.bind("b", hl.dsp.exec_cmd(apps.control_bluetooth))
  hl.bind("k", hl.dsp.exec_cmd(apps.control_kdeconnect))
  hl.bind("d", hl.dsp.exec_cmd(apps.control_display))
  -- Home. Opening the panel on a page and wanting the top level is common
  -- enough to be worth a key, and the toggle treats "control" as "go home"
  -- when a page is already showing.
  hl.bind("c", hl.dsp.exec_cmd(apps.control))

  -- Manual escape, mirroring the power submap.
  hl.bind("escape", hl.dsp.submap("reset"))
end)
