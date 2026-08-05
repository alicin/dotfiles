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
require("lua.submaps.control")
require("lua.startup")

-- ── Per-host overrides (h4l9000 / k3v1n / mcu / …) ──────────────────────────
-- $HOSTNAME is NOT reliably present here. It is a shell variable, not something
-- login(1) or systemd export; on this laptop it only reaches the compositor
-- because a previous session leaked it into `systemd --user` via
-- dbus-update-activation-environment. On a freshly installed machine it is
-- simply absent, and the host module would be skipped in silence -- taking the
-- monitor layout, the workspace rules and the host autostarts with it. Fall
-- back to /etc/hostname, which is always there and always correct.
local function hostname()
  local env = os.getenv("HOSTNAME")
  if env and env ~= "" then return env end
  local ok, name = pcall(function()
    local f = io.open("/etc/hostname", "r")
    if not f then return nil end
    local line = f:read("l")
    f:close()
    return line
  end)
  if ok and name then return (name:gsub("%s+", "")) end
  return nil
end

local host = hostname()
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
