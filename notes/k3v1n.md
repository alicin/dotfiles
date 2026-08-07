# k3v1n — pull checklist

Minisforum V3 convertible tablet (touchscreen + stylus, detachable keyboard).
The machine the tablet/touch work was built on, so most of it is already
applied here. Format and pruning: `notes/README.md`.

## Open

- [ ] 2026-08-07 — **Confirm ghostty's touch scroll feels 1:1 now.**
      `mouse-scroll-multiplier = precision:0.1` in `config/ghostty/config`.
      That number is an exact cancellation, not a taste setting: ghostty's
      GTK layer multiplies every precision (touch/trackpad) delta by a
      hardcoded 10.0 before the config multiplier
      (`src/apprt/gtk/class/surface.zig`, "to get a better response from
      touchpad scrolling"), so 0.1 undoes it and content tracks the finger.
      The catch is that the dock's trackpad shares the knob and now scrolls
      1:1 as well — if that feels sluggish while docked, 0.3–0.5 is the
      compromise band, at the cost of a faster finger. `discrete:` is the
      mouse wheel and is untouched.

- [ ] 2026-08-06 — **Verify rotation on the glass.**
      Rotate (bar button / `Super+Ctrl+R`) and check three things: taps land
      under the finger, the pen tracks, and a physically-horizontal 3-finger
      swipe still switches workspaces. Hyprland never rotates touch itself,
      so `Displays.setTransform` writes the touch/tablet calibration
      matrices and `bin/touch-gestures` counter-rotates the gesture pads.
      If taps land 180° off, swap matrix indices 1↔3 in the `hyprctl -r
      eval` call in `qshell/services/Displays.qml` — one line.

- [ ] 2026-08-06 — **Feel-check the gesture calibration.**
      3-finger workspace swipe is pinned at 2.0× finger travel with a
      release-velocity glide (throw it and it commits); 4-finger window move
      is ~1:1 and now focuses the window under the fingers first. Knobs:
      `sensitivity` per pad in `config/hypr/lua/devices.lua` (the comment
      carries the arithmetic), `GLIDE_S` / `FLICK_MIN_MM_S` at the top of
      `bin/touch-gestures` for the throw.

## Done

- [x] 2026-08-07 → done 2026-08-07 — Ghostty touch scrolling verified working;
      the reason kitty was replaced.

- [x] 2026-08-07 → done 2026-08-07 — Ghostty installed, kitty replaced everywhere.
- [x] 2026-08-07 → done 2026-08-07 — `rose-pine-gtk-theme-full` installed; icon
      set and cursor follow the shell theme's light/dark.
- [x] 2026-08-06 → done 2026-08-06 — Touch stack, rotation matrices, Settings
      window, per-host workspace count (9 here) — all applied on this machine
      as they were written.
