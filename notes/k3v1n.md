# k3v1n — pull checklist

Minisforum V3 convertible tablet (touchscreen + stylus, detachable keyboard).
The machine the tablet/touch work was built on, so most of it is already
applied here. Format and pruning: `notes/README.md`.

## Open

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

- [x] 2026-08-07 → done 2026-08-07 — **Ghostty does not scroll on touch, and no
      setting can make it.** Superseding the earlier claim that it did. GTK4's
      EventControllerScroll handles GDK_SCROLL and GDK_TOUCHPAD_* only, never
      GDK_TOUCH_*; ghostty's surface declares that controller plus a
      GestureClick and nothing else, on 1.3.1 and on upstream main. Measured:
      a synthetic touchscreen drag arrives in a GTK4 client as a real
      touchscreen drag (GestureDrag begin/update/end, src=touchscreen) while a
      controller identical to ghostty's emits zero scroll events, and the same
      drag over a real ghostty window moves nothing. So `mouse-scroll-multiplier`
      is trackpad/wheel only and is back at ghostty's defaults. Ghostty still
      beats kitty here — it receives touch at all, which kitty cannot — but
      scrollback on the glass needs the keyboard or the dock's trackpad.

- [x] 2026-08-07 → done 2026-08-07 — Ghostty installed, kitty replaced everywhere.
- [x] 2026-08-07 → done 2026-08-07 — `rose-pine-gtk-theme-full` installed; icon
      set and cursor follow the shell theme's light/dark.
- [x] 2026-08-06 → done 2026-08-06 — Touch stack, rotation matrices, Settings
      window, per-host workspace count (9 here) — all applied on this machine
      as they were written.
