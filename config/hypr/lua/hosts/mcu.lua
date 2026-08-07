-- mcu — desktop with two LG 4K monitors (one rotated portrait).

-- ── Monitors ────────────────────────────────────────────────────────────────
hl.monitor({
  output   = "desc:LG Electronics LG HDR 4K 0x0007807F",
  mode     = "3840x2160@60",
  position = "0x0",
  scale    = 1.5,
})
hl.monitor({
  output    = "desc:LG Electronics LG HDR 4K 0x0007FDE4",
  mode      = "3840x2160@60",
  position  = "2560x-560",
  scale     = 1.5,
  transform = 1,
})

-- ── Per-host workspaces ─────────────────────────────────────────────────────
local primary   = "desc:LG Electronics LG HDR 4K 0x0007807F"
local secondary = "desc:LG Electronics LG HDR 4K 0x0007FDE4"

hl.workspace_rule({ workspace = "1", monitor = primary, default = true, persistent = true })
for i = 2, 5 do
  hl.workspace_rule({ workspace = tostring(i), monitor = primary, persistent = true })
end

hl.workspace_rule({ workspace = "6", monitor = secondary, default = true, persistent = true })
for i = 7, 10 do
  hl.workspace_rule({ workspace = tostring(i), monitor = secondary, persistent = true })
end

-- ── Host-specific binds ─────────────────────────────────────────────────────
-- Workspace 10: lua/binds.lua covers 1-9 for every host (k3v1n's count); the
-- tenth exists only here and on h4l9000, so its keys live in the host files.
hl.bind("SUPER + F5",         hl.dsp.focus({ workspace = 10 }))
hl.bind("SUPER + SHIFT + F5", hl.dsp.window.move({ workspace = 10, follow = false }))
