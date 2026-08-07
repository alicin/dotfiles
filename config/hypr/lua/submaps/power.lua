-- Power submap: lock / exit / reboot / poweroff / suspend.
-- The 2nd arg "reset" to define_submap auto-returns to the global submap after
-- any dispatch, so we no longer need duplicate `, submap, reset` lines.

local apps = require("lua.apps")

-- The entry bind (Super+Shift+E) lives in lua/binds.lua with a trailing
-- label, so the Super+/ cheatsheet — which only parses that file — can see
-- the one submap whose wrong guess is a reboot. Same move the control submap
-- made; only the submap definition stays here.

hl.define_submap("power", "reset", function()
  hl.bind("l", hl.dsp.exec_cmd(apps.locking))
  hl.bind("e", hl.dsp.exit())
  hl.bind("r", hl.dsp.exec_cmd("systemctl reboot"))
  hl.bind("p", hl.dsp.exec_cmd("systemctl poweroff"))
  hl.bind("s", hl.dsp.exec_cmd("systemctl suspend"))

  -- Manual escape (mirrors original behaviour).
  hl.bind("escape", hl.dsp.submap("reset"))
end)
