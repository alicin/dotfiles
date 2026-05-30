-- Default cross-host workspace assignments.
-- Per-host monitor + workspace overrides live in lua/hosts/<hostname>.lua.

local desktop_monitor = "desc:XXX XYZTIUM 0x950114D8"
local laptop_monitor  = "desc:Samsung Display Corp. ATNA60DL01-0"

hl.workspace_rule({ workspace = "1", monitor = desktop_monitor, default = true, persistent = true })
hl.workspace_rule({ workspace = "2", monitor = desktop_monitor, persistent = true })
hl.workspace_rule({ workspace = "3", monitor = desktop_monitor, persistent = true })
hl.workspace_rule({ workspace = "4", monitor = desktop_monitor, persistent = true })
hl.workspace_rule({ workspace = "5", monitor = desktop_monitor, persistent = true })

hl.workspace_rule({ workspace = "9",  monitor = laptop_monitor, persistent = true })
hl.workspace_rule({ workspace = "10", monitor = laptop_monitor, persistent = true })
hl.workspace_rule({ workspace = "11", monitor = laptop_monitor, persistent = true })
hl.workspace_rule({ workspace = "12", monitor = laptop_monitor, persistent = true })
