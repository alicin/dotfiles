---
name: desktop
description: Maintain ali's desktop environment — Hyprland (Lua config), Toshy (macOS-style keymapper), and the qshell Quickshell shell — plus the k3v1n tablet's touch/rotation/OSK stack. Use when adding or fixing a keybind ("shortcut doesn't fire", "intercepted by Toshy", physical/macOS terms like Cmd, Option, Super), when editing anything under config/hypr, config/toshy, qshell/ or bin/ helper daemons, when validating or restarting these components, or when touch input, gestures, rotation, the on-screen keyboard, or theme sync misbehave.
---

# Maintaining the desktop: Hyprland + Toshy + qshell

One dotfiles repo (`/home/ali/labs/dotfiles`), three hosts: `mcu` (desktop),
`h4l9000` (laptop), `k3v1n` (detachable 2-in-1 tablet, 2560x1600@120 eDP-1 at
scale 1.6667 → logical 1536x960, Goodix touch+stylus digitiser). Host-specific
compositor bits live in `config/hypr/lua/hosts/<hostname>.lua`; everything else
is shared, so a "fix" must not degrade the other two machines.

Per-host pull checklists live in `notes/<hostname>.md` — anything a machine
must do by hand after a pull (install a package, restart a service, verify
hardware). `bin/host-notes` lists what is open here and deletes done entries a
week after they are done; Hyprland runs it with `--notify` at session start.
That replaced the old `desktop-review.md` / `todo-tablet.md` work logs, whose
findings are all either fixed or recorded in git history.

## The modifier scheme (rewritten 2026-07-05 — "native Super")

Toshy grabs the keyboard (EVIOCGRAB) and re-emits through a uinput device;
Hyprland only ever sees Toshy's output. Since 2026-07-05 the modmaps pass the
WM keys through natively (an older version of this skill documented the
pre-2026-07-05 scheme — physical Ctrl→Super, Super→Alt — which is now wrong):

| Physical key   | Emitted (GUI apps)      | Emitted (terminals)  | Role |
|----------------|-------------------------|----------------------|------|
| Left Ctrl      | **Ctrl** (native)       | **Ctrl** (native)    | plain Ctrl |
| Left Super/Win | **Super** (native)      | **Super** (native)   | Hyprland's WM key |
| Left Alt       | **Cmd** (internally Right_Ctrl, "RC" in keymaps) | same | macOS Command |
| Right Ctrl     | **Ctrl** (native)       | **Ctrl** (native)    | plain Ctrl |
| Right Win      | Alt                     | Alt                  | the only input-side Alt |
| Shift, Caps    | unchanged               | unchanged            | |

- **WM binds live on `SUPER`** in `config/hypr/lua/binds.lua` and are hit
  directly from the physical Super key. Aliases defined there: `M`=SUPER,
  `MS`=+SHIFT, `MC`=+CTRL, `MCS`=+CTRL+SHIFT (nothing else — no mod2/MA/CA).
- **Cmd combos** (physical Alt) are rewritten per-app by Toshy keymaps: GUI
  mostly `Cmd+x → Ctrl+x`, terminals terminal-aware (`Cmd+C → Ctrl+Shift+C`).
  A Cmd combo no keymap matches arrives as plain Ctrl+key — that's why the
  macOS-style screenshot binds are `CTRL + SHIFT + 4..7` in binds.lua.
- Terminal context = Toshy's terminals list **plus** the `.*floating_shell.*`
  entry (~line 497) that makes the floating ghostty scratchpads count.
- Ground truth when unsure: `wev -f wl_keyboard:key`, press the combo, read
  `sym:`/`mods:` — that is exactly what Hyprland binds against.

### The Super-passthrough trap (bit twice already)

Stock Toshy keymaps *below* the `user_apps` slice still interpret legacy
`Super-*` combos (they predate the scheme change): GenGUI mapped `Super-Tab` →
`Ctrl+Tab` (overview key dead everywhere), the VSCodes keymap ate
`Super-Grave` (scratchpad dead in VS Code). xwaykeyz is first-match in
definition order, so the fix is a self-map in the
**"ALI - pass physical Super through to Hyprland (WM)"** keymap in the
`user_apps` slice. Current passthrough list:
`a b d e f k n p Tab Shift-Tab Grave Shift-Grave Backspace Delete`.

**Whenever you add a `SUPER + <key>` Hyprland bind**, audit for a hijack:

```bash
grep -n '^\s*C("Super-' ~/.config/toshy/toshy_config.py
```

Any hit *after* the `user_apps` slice (`SLICE_MARK_END: user_apps`) for your
key means you add a self-map to the passthrough keymap.

### Adding/fixing a keybind — procedure

1. Translate the physical combo via the table above; pick `SUPER` for WM
   actions, `CTRL+SHIFT+<x>` only for macOS-Cmd-style app-global combos
   (never one that a terminal keymap emits — check the yazi/ghostty/General
   Terminals keymaps first).
2. Edit `config/hypr/lua/binds.lua` (host-only binds → `hosts/<host>.lua`,
   but note the Super+/ cheatsheet **only parses binds.lua** — trailing
   `-- label` comments are its data source).
3. Run the Super-passthrough audit above if the bind is on SUPER; edit the
   Toshy passthrough keymap if needed (then the Toshy restart procedure below).
4. `hyprctl reload && hyprctl configerrors`.
5. Verify registration + modmask (SHIFT=1 CTRL=4 ALT=8 SUPER=64):
   `hyprctl -j binds | jq -r '.[] | select(.key=="<KEY>") | "\(.modmask) \(.key) \(.dispatcher)"'`
6. **Case-insensitivity:** Hyprland matches bind keysyms case-insensitively
   and fires EVERY match — `MS+"N"` and `MS+"n"` both fire on one press.
   Never register the same modmask+letter twice.
7. To give a *Cmd* combo a WM meaning (Cmd+Q → close), don't bind its GUI
   translation — route it in Toshy: `C("RC-Q"): C("Super-Q")` in the
   "User overrides - Hyprland global shortcuts" keymap, and bind `SUPER+Q`.

App-specific macOS shortcuts (an app "ignores Cmd keys"): add an app keymap in
the `user_apps` slice *before* General GUI — the imv and yazi keymaps there are
the worked examples (match by class, or by title for terminal apps like yazi).

## Hyprland: the Lua parser changes the rules

Config root `config/hypr/hyprland.lua`, modules in `lua/*.lua`, hosts in
`lua/hosts/`, submaps in `lua/submaps/`. API stubs:
`/usr/share/hypr/stubs/hl.meta.lua`.

- **`hyprctl keyword` is always refused** ("keyword can't work with non-legacy
  parsers"). Any script or bind shelling `hyprctl keyword` is silently dead —
  grep for it when something "does nothing".
- **Runtime config writes DO work** via eval, including input options (they
  trip REFRESH_INPUT_DEVICES, re-applying libinput device configs live):
  `hyprctl -r eval 'hl.config({ debug = { vfr = false } })'`
- **Dispatch takes Lua dispatcher forms**, not classic strings:
  `hyprctl dispatch "hl.dsp.workspace.move({ workspace = '3', monitor = 'eDP-1' })"`.
  Classic `hyprctl dispatch moveworkspacetomonitor 3 eDP-1` is pasted verbatim
  into `hl.dispatch(...)` = Lua syntax error. (This killed touch-gestures v1
  and osk-float-rescue v1 — both ported; osk-float-rescue's batch dispatch is
  the reference form. hypr-monitor-manager.sh was deleted outright: workspace
  layout is declarative — per-host workspace rules + a monitor.added/removed
  reload hook, see hosts/h4l9000.lua and hosts/k3v1n.lua.)
- **Output enable/disable/rotate at runtime = `wlr-randr`** (Hyprland
  implements zwlr_output_management_v1); re-enable via `hyprctl reload` so the
  per-host geometry comes back.
- Per-device input tuning: `hl.device({ name = "...", sensitivity = ...,
  accel_profile = "..." })` in `lua/devices.lua` — name-scoped, inert on hosts
  without the device.
- **Prefer native over shelling out** (verified against the 0.56 docs/source):
  `hl.bind` and `hl.gesture` accept LUA FUNCTIONS, so a bind that only writes
  config should call `hl.config({...})` in a lambda, not spawn
  `hyprctl -r eval`. Gestures take `mods` and per-gesture `scale`, live
  callbacks (`start`/`update`/`finish` with deltas), and native actions incl.
  `cursorZoom` (2-finger pinch zoom, `mode="live"`), `close`, `fullscreen`,
  `float`, `special`. `workspace_swipe_touch` is a native 1-finger EDGE swipe
  (must start within ~16px of the screen edge) — alive, not legacy; qshell's
  edge strips mask it on their edges in touch mode. Still NOT native (0.56):
  multi-finger touchscreen gestures, touch/tablet rotation auto-follow, an
  IPC event for transform changes, OSK/exclusive-zone float handling — the
  bridge/helpers exist for exactly those.

## Toshy: validation, restarts, and the upgrade trap

`~/.config/toshy/toshy_config.py` is a **symlink** into the repo
(`config/toshy/toshy_config.py`); prefs live in
`toshy_user_preferences.sqlite` (also tracked). Verify with
`sqlite3 ~/.config/toshy/toshy_user_preferences.sqlite "SELECT name,value FROM config_preferences"`.

**Edit → validate → restart → verify** (always all four):

```bash
python3 -m py_compile ~/.config/toshy/toshy_config.py
systemctl --user restart toshy-config.service
sleep 3
grep -q XWayKeyz /proc/bus/input/devices && echo grabbed   # the real signal
systemctl --user show toshy-config.service -p NRestarts     # must stay 0
```

Don't trust journal silence — Python block-buffers stdout; the grab + NRestarts
are the truth.

**The upgrade trap (it already fired once, 2026-08-05):** the entire native-
Super scheme is in-place edits of stock blocks *outside* the `SLICE_MARK`
blocks (`# ALI:` comments at the LEFT_CTRL/LEFT_META self-maps, the
`.*floating_shell.*` terminals entry, the `getattr()` guards). A Toshy
install/upgrade regenerates the file — the 2026-08-05 run reset even the
`user_apps` slice; only re-symlinking the repo copy restored it. After ANY
Toshy upgrade:

```bash
readlink -f ~/.config/toshy/toshy_config.py   # must point into the repo
grep -q '# ALI: Super stays native' "$(readlink -f ~/.config/toshy/toshy_config.py)" && echo scheme-intact
```

If broken: re-link the repo copy (command in `config/toshy/README.md`), then
diff the installer's `toshy_config.py.installed-*` backup for upstream changes
worth merging. Upstream base of the tracked config: toshy commit
`17dc24c4c3`, template `20260615`.

**Cross-machine hazard:** the file is shared between xwaykeyz 1.21 (h4l9000)
and 1.25 (k3v1n). API drift between them is handled with `getattr(cnfg, "X",
default)` / try-except guards (see the Caps2Esc and keyboard_layout_correction
blocks for the pattern) — a bare missing attribute inside a modmap `when`
lambda kills EVERY modmap at key-event time with no service error.

`timeouts(suspend=0.1)` in the `keymapper_api` slice is load-bearing for
Super+mouse-drag (first click used to miss); don't raise it.

## qshell: never restart it yourself

**Restarting qshell is ali's call** — it tears down the bar and every panel of
the live session, and a bad commit turns the restart into a crash loop with no
bar at all. Validate out-of-process:

- `/usr/lib/qt6/bin/qmllint <file>` — the Qt6 one; `/usr/bin/qmllint` is a
  Qt5 stub that only checks syntax. Plain `QtQuick`/`Quickshell.*` imports
  resolve as-is; `qs.*` imports need a `-I` shadow tree with generated qmldir.
- Runtime behavior: throwaway `qs -p <scratchdir>` config with its own
  settings.json and only the components under test (IPC is namespaced per
  config path — no collision with the live shell).
- The live file watcher can wedge after a failed reload:
  `touch qshell/shell.qml` re-triggers it (edits to `services/*` singletons
  alone don't always).

Conventions and traps:

- `Item` already owns `transform scale rotation state data children enabled` —
  naming a property after one is a FINAL-override crash (took the shell down
  once via `RotateStatus.transform`).
- `qshell/settings.json` is a live-edit surface: every value read from it needs
  a **read-path** clamp/normalize (setter-only validation is a known bug class).
- **The terminal is ghostty** (since 2026-08-07; kitty's Wayland backend has
  no wl_touch support at all, and `touch_scroll_multiplier` is a *touchpad*
  knob — there was no setting to fix that). Config `config/ghostty/config`,
  reloads on **SIGUSR2**, theme via the `config-file = current-theme` include
  that theme-sync rewrites. A touchscreen is a `precision` device to ghostty,
  so `mouse-scroll-multiplier = precision:…` is the finger-scroll knob — and
  it scales the trackpad by the same factor, they cannot be split. Gotcha:
  ghostty creates its own `~/.config/ghostty/` on first run, which blocks the
  profile symlink; `ghostty +show-config | grep theme` empty means re-link.
- Debug/IPC handles: `qs -c qshell ipc call osk status`,
  `... tablet status`, `... display rotate|reset|transform N`,
  `... settings open|close|toggle|section <name>` (the standalone Settings
  window — `modules/control/SettingsWindow.qml`, macOS-sidebar shaped, state
  in `services/SettingsUi.qml`; there is no Control Center settings page),
  `... theme set <name>` (theme changes drive `scripts/theme-sync.sh` through
  `services/ThemeSync.qml`).
- The shell's workspace count is **per-host**: `workspacesByHost` in
  settings.json (k3v1n 9, mcu 10, h4l9000 12; `Settings.hostname` reads
  /etc/hostname). Compositor-side, binds.lua covers workspaces 1-9 for every
  host and the extra ones live in `hosts/mcu.lua` / `hosts/h4l9000.lua` —
  keep the two sides in sync when changing a host's count.

## The k3v1n touch stack

```
digitiser (PNP0C50 touch+stylus, EVIOCGRAB'd by bin/touch-gestures)
 ├─ qshell-touch-screen  clone: 1-2 finger input, apps/OSK/edge strips
 ├─ qshell-touch-pad     virtual touchpad: 3-finger sets → workspace/overview
 ├─ qshell-touch-move    virtual touchpad: 4-finger sets → interactive move
 └─ stylus node          NOT grabbed — reaches Hyprland directly
bin/tablet-sensors   → services/Tablet.qml   (keyboard dock, hinge, orientation)
bin/osk-focus-watch  → services/Osk.qml      (zwp_input_method_v2 text focus)
bin/osk-float-rescue                          (lifts floats above the OSK)
```

**Rotation** (Hyprland 0.56 does NOT rotate touch with the output — verified
in source; `input:touchdevice:output` only picks the mapping box):

- `services/Displays.qml setTransform()` rotates the picture with `wlr-randr`
  AND writes `input:touchdevice:transform` + `input:tablet:transform` via
  `hyprctl -r eval` — that rotates taps (the clone) and the stylus.
- `bin/touch-gestures` counter-rotates the two gesture pads itself (pointer
  devices have no calibration matrix) by watching `wl_output` — covers
  external `wlr-randr` too. The matrices are *not* updated by external
  rotations, only qshell-driven ones.
- If taps land 90° the wrong way on hardware: swap transform 1↔3 in
  Displays.qml's eval call (one line).

**Gesture speed** is calibrated in `lua/devices.lua` (`qshell-touch-pad`
s=-0.876 flat = 2.0× finger, `qshell-touch-move` s=-0.68 flat ≈ 1:1) — the
math and tuning table are in that file's comment. **Inertia** for the 3-finger
swipe lives in `bin/touch-gestures` (GLIDE_* constants): release velocity is
measured over the last ~100ms and the virtual fingers glide on decelerating,
so a thrown flick commits without crossing the distance threshold. Don't
instead lower the global `workspace_swipe_min_speed_to_force` — it is tuned to
trackpad-scale deltas and would make the real trackpad force-commit on any
brisk swipe. libinput gesture deltas are raw units × accel factor; advertised
resolution is NOT a speed knob (the old PAD_RES was a placebo). Don't touch
global `workspace_swipe_distance` — it retunes the real trackpad too.

**Restarting touch-gestures** (needed after editing it; crash-safe — if it
dies the kernel drops the grab and raw touch keeps working):

Run the kill and the relaunch as **two separate shell invocations** — never one
compound command. `pkill -f` matches the invoking shell's own command line, and
a compound line inevitably contains the daemon's literal path in its launch
half, so it kills your own shell before the launch runs (this happened twice).
The `[-]` in the kill pattern keeps the pattern itself from self-matching:

```bash
pkill -f 'bin/touch[-]gestures'          # invocation 1: kill only
```
```bash
setsid nohup /home/ali/labs/dotfiles/bin/touch-gestures >> ~/.cache/qshell/touch-gestures.log 2>&1 < /dev/null &
sleep 3; hyprctl -j devices | jq -r '.mice[].name,.touch[].name' | grep qshell   # expect all three
```

(Autostart lives in `hosts/k3v1n.lua` `hyprland.start`; the manual launch is
only for mid-session redeploys.)

**Never run touch-gestures' injection tests on the live machine** — virtual
touchscreens are adopted by the running compositor and synthetic gestures
drive the real session.

**The device-type gate** (the shell is shared with two non-touch machines):
`bin/tablet-sensors` reports whether a direct-multitouch touchscreen exists,
and `Tablet.hasTouchscreen` gates the whole stack — hardware-auto can only
resolve to tablet mode, `osk-focus-watch` only binds the seat's input-method
slot, and rotation only writes touch/tablet calibration matrices, when one is
present. The keyboard heuristic ALONE must never flip a machine into touch
mode (a laptop's internal keyboard can hide behind the phantom filter; WMI
drivers fake SW_TABLET_MODE). Explicit overrides stay honored everywhere:
`tabletMode: "tablet"` and `osk: "on"` work without a touchscreen. When adding
a new touch feature, key it on `Settings.touchActive` (or
`Tablet.hasTouchscreen` for plumbing) — never on the keyboard heuristic, and
never unconditionally. Check with `qs -c qshell ipc call tablet status`.

## Deployment etiquette (who restarts what)

| Component | Apply | Safe for Claude to do |
|---|---|---|
| Hyprland config | `hyprctl reload` + `configerrors` | yes |
| Toshy config | procedure above | yes (verify after) |
| touch-gestures / tablet-sensors / osk-* | pkill + relaunch | yes, with verification + rollback ready |
| qshell | `systemctl --user restart qshell` | **no — ali's call**; validate out-of-process |
| greetd/system files | `scripts/greeter.sh` (overwrites /etc from repo) | only with ali; check repo copy matches deployed FIRST |
