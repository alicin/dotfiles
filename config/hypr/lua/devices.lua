-- Per-device input config.
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/

hl.device({
  name        = "compx-2.4g-wireless-receiver",
  sensitivity = -0.4,
})

-- (The two Razer Naga entries that used to sit here set no properties at all
-- — an hl.device rule with only a name does nothing.)

-- ── k3v1n's touchscreen gesture pads (bin/touch-gestures) ───────────────────
-- Two virtual touchpads the gesture bridge replays touchscreen contact sets
-- onto: `qshell-touch-pad` carries 3-finger sets (workspace swipe + overview),
-- `qshell-touch-move` carries 4-finger sets (interactive window move). They
-- are split because the two gestures render deltas differently (workspace:
-- delta*width/swipe_distance; move: delta*1px -- a ~5x gap one sensitivity
-- cannot bridge). Inert on hosts without the devices.
--
-- Without these rules the pads inherit the GLOBAL mouse tuning (sensitivity
-- 0.1 + adaptive accel in lua/options.lua), which measured out at 18-96x
-- finger speed with a 5.3x swing across the accel curve -- the "screen moves
-- much faster than my fingers" bug. Flat profile makes the mapping constant;
-- sensitivity sets the ratio.
--
-- The math (per-axis units are 54/mm after the bridge's isotropic mapping;
-- flat accel factor = 0.2968*(1+s); workspace renders delta*1536px/300):
--   screen px per finger mm = 54 * 0.2968*(1+s) * 5.12      [workspace]
--   1:1 finger-follow needs 5.07 px/mm -> s = -0.94 (transition = full panel
--   width). s = -0.876 = 2.0x finger (ali's pick): transition ~= half panel,
--   distance-commit at a quarter -- and short throws land anyway, because
--   bin/touch-gestures adds INERTIA on release (a decelerating glide of the
--   virtual fingers; see the GLIDE_* constants there). Speed ratio is tuned
--   here; throw feel is tuned there.
-- For the move pad the window tracks delta directly: 1:1 needs
--   54 * 0.2968*(1+s) = 5.07  ->  s = -0.68 (floating windows under-finger;
--   tiled moves render at half that by design).
-- workspace_swipe_distance stays global and untouched: changing it would
-- re-tune the real usb-keyboard-touchpad too.
hl.device({
  name          = "qshell-touch-pad",
  sensitivity   = -0.876,
  accel_profile = "flat",
})

hl.device({
  name          = "qshell-touch-move",
  sensitivity   = -0.68,
  accel_profile = "flat",
})
