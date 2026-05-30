-- Hyprland Lua configuration entry point.
-- See https://wiki.hypr.land/Configuring/Start/
--
-- Load order matters where modules reference each other. Pure-data modules
-- (apps, theme) are required first so subsequent modules can pull values from
-- them. Each require() runs in its own scope, so a runtime error in one module
-- does not stop the others from loading.

-- ── Make `lua/` and the config dir discoverable to require() ────────────────
-- Hyprland's Lua sandbox does not necessarily add the config dir to
-- package.path automatically. Prepend both forms so `require("lua.apps")` and
-- `require("apps")` style imports work.
local config_dir = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr"
package.path = config_dir .. "/?.lua;"
            .. config_dir .. "/?/init.lua;"
            .. package.path

-- ── Core configuration ──────────────────────────────────────────────────────
require("lua.env")
require("lua.theme")        -- pure data, no side effects
require("lua.apps")         -- pure data, no side effects
require("lua.options")
require("lua.animations")
require("lua.devices")
require("lua.monitors")
require("lua.rules")
require("lua.binds")
require("lua.submaps.power")
require("lua.startup")

-- ── Per-host overrides (h4l9000 / k3v1n / mcu / …) ──────────────────────────
local host = os.getenv("HOSTNAME")
if host and host ~= "" then
  local ok, err = pcall(require, "lua.hosts." .. host)
  if not ok then
    -- Surface but don't abort — missing host module is normal on new machines.
    hl.notify({
      message = "host module 'lua.hosts." .. host .. "' not loaded: " .. tostring(err),
      timeout = 5000,
    })
  end
end
