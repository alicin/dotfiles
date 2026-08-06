-- Hyprland keyword options.
-- One unified hl.config() call.

local theme = require("lua.theme")

hl.config({
  general = {
    gaps_in                 = 4,
    -- Tight under the qshell bar, roomy on the other sides.
    gaps_out                = { top = 4, right = 12, bottom = 12, left = 12 },
    border_size             = 4,
    layout                  = "dwindle",
    resize_on_border        = true,
    extend_border_grab_area = 20,
    -- allow_tearing lives in hosts/h4l9000.lua with the rest of the Looking
    -- Glass accommodations -- only that host runs the LG client.
    col = {
      active_border   = theme.active_border,
      inactive_border = theme.muted,
    },
  },

  decoration = {
    rounding       = 12,
    rounding_power = 4.0,
    shadow = {
      enabled      = true,
      range        = 200,
      render_power = 4,
      color        = "rgba(1a1a1aaf)",
      offset       = { 0, 20 },
      scale        = 0.9,
    },
  },

  animations = {
    enabled = true,
  },

  misc = {
    -- Note: original config set layers_hog_keyboard_focus twice (false then true);
    -- the latter wins. Kept the effective value (true) here.
    layers_hog_keyboard_focus = true,
    disable_splash_rendering  = true,
    disable_hyprland_logo     = true,
    font_family               = "OperatorMono Nerd Font",
  },

  -- debug.vfr = false (for Looking Glass frame pacing) used to be forced here
  -- GLOBALLY, burning battery on the tablet for a VM only h4l9000 can run --
  -- and on the claim that "there is no runtime eval", which is false:
  -- `hyprctl -r eval 'hl.config({ ... })'` works. It now lives in
  -- hosts/h4l9000.lua; everywhere else VFR stays on (the default).

  binds = {
    allow_workspace_cycles = true,
    scroll_event_delay     = 50,
  },

  dwindle = {
    -- `pseudotile` is no longer a dwindle config option in 0.55; it became a
    -- per-window action only. Use `hl.dsp.window.pseudo()` from a keybind.
    preserve_split = true,
    -- Drag-move a tiled window to its exact drop position (insert at the cursor)
    -- instead of only swapping with the target on release. Makes Super+drag
    -- actually reposition tiled windows around the layout.
    precise_mouse_move = true,
  },

  master = {
    -- "slave" was valid in 0.54; in 0.55 the accepted values are master/slave/inherit.
    new_status = "slave",
  },

  gestures = {
    workspace_swipe_touch = true,
  },

  xwayland = {
    force_zero_scaling = true,
  },

  input = {
    kb_layout    = "us",
    kb_model     = "",
    follow_mouse = 1,
    sensitivity  = 0.1,
    accel_profile = "adaptive",
    touchpad = {
      natural_scroll       = true,
      scroll_factor        = 0.3,
      clickfinger_behavior = true,
      tap_to_click         = false,   -- was `tap-to-click = false` (hyphen variant)
      disable_while_typing = true,
    },
    touchdevice = {
      output = "eDP-1",
    },
    tablet = {
      output = "eDP-1",
    },
  },
})
