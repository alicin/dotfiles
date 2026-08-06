# Desktop review — qshell + Hyprland + Toshy (k3v1n)

2026-08-06. A 16-agent review (8 dimensions, every finding independently re-verified by an
adversarial second agent) over the shell, the Hyprland Lua config, the Toshy config, the
`bin/` helper daemons, and the session plumbing. Claims below were checked against the
**running** compositor (Hyprland 0.56.2 @ efb5099 — the source of that exact commit was
cloned and read), libinput 1.31.3 source, xwaykeyz/Toshy source, and live `hyprctl` /
evdev / sqlite state — not just the repo text. 68 findings raised, 67 survived
verification, 1 refuted. Deduplicated across dimensions below.

Severity: **high** = broken behavior you actually hit, or changes that will silently
revert; **mid** = wrong under realistic conditions, dead config, maintenance traps;
**low** = robustness/polish; **nit** = cosmetic.

---

## Top 3 — fixed in this pass

### 1. Screen rotates, touch/stylus/gestures don't ✅ FIXED (touch + gestures + stylus; needs a finger test)

Your reported bug #1, confirmed at source level. Hyprland 0.56.2 **never** rotates touch
input with the output: `Touch.cpp:40` maps normalized device coords linearly onto the
monitor's logical box; `input:touchdevice:output = eDP-1` only picks _which_ box (the
comment in `hosts/k3v1n.lua:73-78` claiming it applies the transform was wrong, as was the
same claim in `services/Displays.qml` and `todo-tablet.md`). The only rotation hook is the
`input:touchdevice:transform` / `input:tablet:transform` libinput calibration matrix —
config-time only, and it was never set (live: `0, set:false`). On top of that, the
3/4-finger gestures ride `bin/touch-gestures`' virtual **touchpad**, a pointer device with
no calibration path at all — so even with the matrix set, a physically-horizontal swipe on
a rotated screen would register on the wrong axis (workspace swipe and overview swipe
would swap).

**Fix applied (two coordinated halves, no overlap):**

- `qshell/services/Displays.qml` `setTransform()` now also runs
  `hyprctl -r eval 'hl.config({ input = { touchdevice = { transform = T }, tablet = { transform = T } } })'`
  when rotating eDP-1. Verified against source that runtime `hl.config` writes schedule
  `REFRESH_INPUT_DEVICES` (`LuaBindingsConfigRules.cpp:1008`), which re-applies the
  calibration matrices live (`PropRefresher.cpp`) — this rotates **taps** (the
  `qshell-touch-screen` clone is a touch device) and the **stylus** (tablet device).
  Probed live with a no-op write: the eval path works.
- `bin/touch-gestures` now watches `wl_output` (pywayland, already a dependency of
  `osk-focus-watch`) and counter-rotates the coordinates it replays onto the **gesture
  pads** — the compositor matrix can't reach those. Pad coordinates are also converted to
  an isotropic unit space first, so rotated swipes preserve physical distance.

**Verify on hardware** (I can't press the glass): rotate via the bar button, then check
taps land under the finger, the pen tracks, and a physically-horizontal 3-finger swipe
still switches workspaces. If taps land 180° off, swap matrix indices 1↔3 in
`Displays.qml`'s eval (one-line change). External `wlr-randr` rotations bypass qshell and
won't set the matrices — qshell is the rotation surface (see Low list).

### 2. Touch gestures 18–96× faster than the finger ✅ FIXED (needs a feel pass)

Your reported bug #2, quantified. The bridge replays raw digitiser units (54/mm X, 86/mm Y)
onto a virtual touchpad, and libinput's gesture path is **resolution-blind**: swipe deltas
are raw device units × accel factor (verified in libinput 1.31.3 source — the
resolution-normalizing coefficients are computed but never applied to gestures). The pad
inherited the **global** `sensitivity 0.1` + `accel_profile adaptive` meant for mice
(`devices.lua` configured only desktop mice), and Hyprland renders workspace offset as
`delta × 1536 / 300`. Net: **18×** finger speed at slow speeds, **96×** on a flick, with a
5.3× swing from adaptive accel — a workspace transition completed in 3–17 mm of finger
travel. The `PAD_RES` knob the file documented for exactly this was a placebo (see Mid).
Bonus defects: the pad advertised 60/60 res for a 54/86 device, making vertical gestures a
further 1.59× hotter than horizontal and biasing diagonal swipes toward the overview
gesture; and the workspace and window-move gestures need different calibrations (their
pixel mappings differ 5×), which one device can't provide.

**Fix applied:**

- `bin/touch-gestures` now feeds **two** pads in isotropic units (both axes 54 units/mm):
  `qshell-touch-pad` (3-finger → workspace/overview) and `qshell-touch-move`
  (4-finger → window move). Real per-axis resolutions are read from the digitiser and
  advertised on the touchscreen clone.
- `config/hypr/lua/devices.lua`: per-device `hl.device` rules pin both pads to
  `accel_profile = "flat"` with sensitivity −0.88 (workspace: ~1.9× finger, transition
  commits at ~¼ panel width) and −0.68 (window move: ~1:1 under the finger). Verified
  inert for mcu/h4l9000 and for the real usb-keyboard-touchpad; `workspace_swipe_distance`
  deliberately untouched (global — would wreck trackpad feel).
- A tuning table is in the `devices.lua` comment: −0.94 gives exact 1:1 workspace follow
  but a half-panel commit distance; each step is documented with the formula.
- Follow-up (same day, per ali): workspace pad pinned at exactly **2.0×** (s = −0.876) and
  the bridge grew **inertia** — release velocity over the last ~100 ms turns into a
  decelerating glide of the virtual fingers, so a thrown flick commits the workspace
  switch (Hyprland's own `min_speed_to_force` path is average-delta based and unreachable
  at touchscreen delta scale; lowering it globally would wreck the real trackpad).

### 3. Physical Super+Tab (and Super+` in VS Code) eaten by Toshy ✅ FIXED

The keybind-situation centerpiece. Since the 2026-07-05 scheme change (physical Super =
native Super), Toshy's _stock_ keymaps below the `user_apps` slice still interpret legacy
`Super-*` combos: "GenGUI overrides" maps `Super-Tab`/`Super-Shift-Tab` → `Ctrl+Tab` in
**every** app including terminals (`toshy_config.py:5833-5843`), so the overview key —
listed in the cheatsheet — never fired from the physical keyboard anywhere; and the
VSCodes keymap maps `Super-Grave` → `Ctrl-Grave` (`:5054-5055`), so the scratchpad keys
toggled VS Code's integrated terminal instead. The `ALI` passthrough keymap wins by
first-match order but only covered `a b d e f k n p Backspace Delete`.

**Fix applied:** `Super-Tab`, `Shift-Super-Tab`, `Super-Grave`, `Shift-Super-Grave`
self-maps added to the passthrough keymap in the `user_apps` slice; Toshy restarted and
verified (config compiles, service up, keyboard grabbed, no restarts). Nothing is lost:
in-app tab cycling is physical `Ctrl+Tab` (native now), VS Code's terminal toggle is
physical `Ctrl+`` `. Not silently added: `Super-c`/`Super-x` passthroughs (VSCodes also
eats those) — that trade-off is yours to call, see High #4's audit note.

---

## High

**H4. The whole 2026-07-05 modifier scheme lives outside Toshy's upgrade-safe slices — and
an upgrade already ate it once.** ✅ FIXED — `scripts/toshy-install.sh` now ends with a
canary (tracked-symlink check + `# ALI: Super stays native` grep, hard-fails before the
service restart), and `config/toshy/README.md` gained "The upgrade trap": the 2026-08-05
incident, the full out-of-slice inventory, the upstream base SHA, and the restore
procedure. Original finding: `config/toshy/toshy_config.py:2383,2399,2493-2514,497` —
the native-Ctrl/native-Super modmap edits, the floating-terminal class entry, and the
`getattr()` guards are in-place edits of stock blocks outside `SLICE_MARK`s. The verifier
found the smoking gun: a Toshy install ran **2026-08-05 18:16** and its generated config
(`~/.config/toshy/toshy_config.py.installed-20260805-181702`) contains _zero_ ALI edits —
even the `user_apps` slice was reset; only the manual re-symlink at 18:17 saved the
scheme. Next time there'll be no error to find: physical Super silently reverts to Alt and
every SUPER bind dies at once. **Fix:** add a canary to `scripts/toshy-install.sh`'s
sanity-check section (`grep -q 'ALI: Super stays native' "$(readlink -f ~/.config/toshy/toshy_config.py)"`

- symlink-into-repo check, fail loudly), record the upstream base SHA (`17dc24c4c3`,
  template `20260615`) in `config/toshy/README.md` with the restore procedure, and keep an
  out-of-slice-edit inventory there. A grep audit for remaining hijack surface:
  `grep -n '^\s*C("Super-' toshy_config.py` below line 4198.

**H5. The getattr() Caps2Cmd/Caps2Esc_Cmd fix is uncommitted.** The only working-tree diff
in `config/toshy/` — and it's load-bearing: without it, xwaykeyz 1.25's settings class
(which dropped those attributes) raises per-key-event `AttributeError`s inside
`apply_modmap` and **no modmap applies at all** (that's the "Super stopped reaching
Hyprland" incident). Verified correct for both machine generations (1.21 reads the real
values, 1.25 falls back to False = the sqlite state). Any `git checkout -- config/toshy/`
loses it; h4l9000 pulling main today gets the broken file. ✅ FIXED — committed as
`65a2157d` (the Super-Tab/Grave passthroughs went in separately as `b777a55e`).

**H6. `bin/hypr-monitor-manager.sh` is dead under the Lua parser.** Line 58 issues classic
`hyprctl dispatch moveworkspacetomonitor …`, which the Lua config manager refuses
(wrapped verbatim into `hl.dispatch(...)` = syntax error), with `2>/dev/null || true`
eating the evidence — the same DOA class that hit touch-gestures v1 and osk-float-rescue,
never ported here. All three monitor binds (`Super+Ctrl+M/E/L`) and the Display page's
layout buttons (`Displays.qml:53`) silently do nothing, on every host. ✅ FIXED — ported to the
Lua form `hl.dsp.workspace.move({ workspace = …, monitor = … })` with refusals logged
instead of `2>/dev/null`'d; verified live (workspaces 1–9 move `ok`; nonexistent
workspace 10 now logs "Workspace not found" instead of vanishing). Because the port
_arms_ the old `Super+Ctrl+L` collision with resize-wider, `setup-laptop` moved to
`Super+Ctrl+B` ("built-in") — the review's suggested `MCS` home would have collided
with the `MCS+l` nudge bind the same way. **Then SUPERSEDED** (wiki-check pass): the
whole job is declarative natively — per-host workspace rules recompute on reload, and a
`monitor.added/removed` hook reloads automatically (h4l9000's existing pattern; k3v1n
now mirrors it: docked = 1–5 on the horizontal LG, 6–8 on the portrait, 9 home on the
panel). The script, its udev-rule installer (`scripts/monitor-manager.sh`), the deployed
udev rule, and the extra keybinds are gone; `Super+Ctrl+M` remains as a `hyprctl reload`
nudge and the Display page's three layout chips collapsed to one "Re-apply layout".

**H7. Repo greetd config would regress the live uwsm session.** ✅ FIXED —
`system/etc/greetd-config.toml:19` said `--cmd Hyprland` while the deployed file runs
`--cmd 'uwsm start -e -D Hyprland hyprland.desktop'`; `scripts/greeter.sh` overwrites
deployed-from-repo on any diff, so the next provision would have dropped the
systemd-managed session. Repo copy updated to match deployed.

**H8. `debug:vfr = false` is global — permanent full-rate rendering on the battery
tablet.** `options.lua:61`, justified by a Looking Glass client that exists only in
h4l9000's profile. k3v1n composites every frame at 120 Hz while idle for nothing. The
comment's premise ("no runtime eval, so VFR can only be set at config-load time") is now
false — `hyprctl -r eval` works and this repo already uses it. ✅ FIXED — `vfr = false`,
`allow_tearing = true` and the LG `immediate` window rule all moved to
`hosts/h4l9000.lua` (hosts load last, so they override the shared defaults); verified
live on k3v1n: `debug:vfr` is back to `true` and `allow_tearing` to `false`. Stale
comments corrected.

---

## Mid

**M1. Case-duplicate binds double-fire.** Hyprland matches bind keys case-insensitively
and dispatches _every_ match (verified in `KeybindManager.cpp` + live `hyprctl binds`):
`binds.lua:105-106` registers the refresh toggle twice (`MS+N` and `MS+n`) — one press
spawns two racing `toggle-edp-refresh.sh` instances (whose `HIGH_REFRESH=240` is
h4l9000's panel; k3v1n tops out at 120). And `binds.lua:75` (`MC+l` resize wider) collides
with `binds.lua:109` (`MC+L` monitor-manager setup-laptop) — today the script side is dead
(H6), but every resize-wider press spawns it. ✅ FIXED — the `MS+n` duplicate is
deleted (one registration, one script instance), and `toggle-edp-refresh.sh` now derives
the high rate from `availableModes` at the current resolution — which on this panel is
**165 Hz**, so the toggle gains a mode the hardcoded 240 never reached. (`MC+L` collision
was resolved with the H6 port — setup-laptop lives on `MC+B`.)

**M2. Super+scroll zoom has never worked.** `binds.lua:120-123` shells
`hyprctl -q keyword cursor:zoom_factor …` — refused under the Lua parser, `-q` hides the
refusal. Same class as the known-dead `MC+D`/`MC+S` xwayland toggles (110-111). ✅ FIXED — both zoom
directions and both xwayland toggles ported to `hyprctl -r eval 'hl.config({ … })'`
(also one process per scroll tick instead of three); the zoom form live-tested.

**M3. Physical Right-Ctrl is Super in GUI apps, Ctrl in terminals.** Leftover right-side
mirror of the old scheme: `toshy_config.py:2373` still maps `RIGHT_CTRL → RIGHT_META` in
the GUI modmap (terminal block already maps it to `LEFT_CTRL`). Right-Ctrl+C launches VS
Code, Right-Ctrl+W opens Chrome, Right-Ctrl+Q closes the window — GUI only. ✅ FIXED — mapped to
`LEFT_CTRL` with an `# ALI:` marker (same output the terminal block already used), Toshy
restarted clean. Right-Ctrl is now plain Ctrl everywhere. Uncommitted — commit with the
next Toshy batch.

**M4. Workspaces 10–12 are pinned to h4l9000's absent OLED panel on k3v1n.** Live
workspacerules show 10/11/12 → `desc:Samsung Display Corp…` here; `hosts/k3v1n.lua:33`
stops its loop at 9 while `binds.lua` binds F5–F7 to 10–12 — so those workspaces aren't
persistent and behave inconsistently. `monitors.lua`'s defaults (placeholder
`XXX XYZTIUM` monitor) are dead on every host. ✅ FIXED, per ali's note the
other way around: **k3v1n keeps 9** — `monitors.lua`'s dead default rules are deleted
outright (each host declares its full set now), `binds.lua` covers workspaces 1–9 for
everyone, and the 10th (mcu) / 10–12th (h4l9000) keys moved into those host files. The
shell's workspace count became per-host too (`workspacesByHost` in settings.json:
k3v1n 9, mcu 10, h4l9000 12) — verified live: the bar shows exactly nine pills and
`workspacerules` lists 1–9 only.

**M5. The screenshot "Annotate" button is dead.** `capture.sh` adds it to every screenshot
notification, `Capture.qml:193` execs `swappy` — not installed, not in any k3v1n package
list. ✅ FIXED — both: the
button is gated on `command -v swappy` (no more dead action) and `swappy` is in
k3v1n's `pacman.txt` for the next provision.

**M6. `toshy-hypr-bind` skill documents the pre-2026-07-05 scheme.** Its physical→emitted
table, translation table, alias list, and Alt+F4 anecdote were all inverted relative to
the active config — following it produced dead binds. ✅ FIXED — replaced by
`.claude/skills/desktop/` (renamed), rewritten from the verified current scheme and
broadened to full desktop maintenance (Hyprland + Toshy + qshell + the touch stack).

**M7. ThemeSync fires theme-sync.sh on every shell start and live-reload.** The
`Component.onCompleted` seed reads the JsonAdapter _default_ before the async settings
load delivers the real theme, so the change-guard sees default→saved as a real change —
on every login and every watched-file reload: kitty SIGUSR1 hitch, portal writes, VS Code
settings.json rewrite. ✅ FIXED — `Settings.ready`
now exists (set in `onLoaded`/`onLoadFailed`), ThemeSync gates on it and seeds from it;
the default→saved flip no longer counts as a change.

**M8. A dead osk-focus-watch leaves the OSK trusting stale focus.** `Osk.qml:152`'s
`onExited` restarts the helper but never clears `focusAvailable`/`textFocus`, so the
documented "focus unknown → always-up-while-undocked" fallback never engages; a crash-
looping helper means no keyboard when tapping into a text field. Same pattern in
`Tablet.qml:125` (`ready`/`keyboardAttached` never invalidated). ✅ FIXED — both `onExited`
handlers clear their stale state (`focusAvailable`/`textFocus` in Osk, `ready` in
Tablet), so the documented fallbacks actually engage while a helper is down.

**M9. `Settings.osk` is validated only in the setter.** A hand-edit of settings.json (the
documented live-edit surface) to `"On"`/`"of"` leaves the OSK in no mode: never raises,
but the helper keeps holding the seat's one input-method slot. The numerics got read-path
clamps in the last review round; the mode strings didn't. ✅ FIXED — both mode strings
normalized on the read path like the numerics.

**M9b (ali): Settings moved to its own macOS-like window.** ✅ DONE — the Control Center's
settings drill-down page is gone; Settings is now a real floating toplevel
(`modules/control/SettingsWindow.qml`, 720×540, Hyprland floats `org.quickshell`
natively): sidebar with colored icon chips and seven sections (Appearance / Desktop /
Tablet & Touch / On-screen Keyboard / Weather / Clipboard / System), one section shown at
a time, Esc or Super+Q closes. Opened from the Control Center gear or
`qs -c qshell ipc call settings open|toggle|section <name>` (state in
`services/SettingsUi.qml`). Verified live: window floats, all sections render, controls
drive the same setters.

**M10. Overview draws landscape geometry in portrait.** `Overview.qml:226` and
`OverviewWindow.qml:33` divide the IPC `width/height` (untransformed mode size — verified
in `HyprCtl.cpp`) by scale with no transform term. Rotate + open overview: cells keep
1536×921 aspect for 960×1497 workspaces, thumbnails at ~40% wrong scale. ✅ FIXED — both files
swap width/height on odd transforms, reading the transform from the overview's own
fresh `monitors` fetch (not the stale `lastIpcObject`).

**M11. The bar's two tablet buttons are 30–37 px targets, adjacent, and one rotates the
screen.** `OskStatus.qml:27` / `RotateStatus.qml:29` size to `barInner` with no
`touchTarget` floor and StateLayer's slop is vertical-only — a thumb missing the OSK
toggle by half a fingertip rotates the panel, and on glass there's no right-click to
reach the reset. ✅ FIXED — both buttons floor
their width at `Appearance.touchTarget` (0 outside touch mode, desktop hosts unchanged).

**M11b (ali): bar window title capped at 60 chars.** ✅ DONE — hard cap in `Bar.qml`'s
title binding (59 chars + ellipsis), on top of the existing layout-width elide.

**M11c (ali): k3v1n shows only 9 workspaces.** ✅ DONE — see M4: nine everywhere
(binds, rules, bar, overview), with mcu/h4l9000 keeping their 10/12 via host files and
`workspacesByHost`.

**M12. touch-gestures holdback was clocked by the 0.2 s select tick.** ✅ FIXED with #2 —
a motionless press reached apps up to 200 ms late (kernel ABS dedup means a still finger
emits nothing); the select timeout now counts down the actual holdback remainder.

**M13. touch-gestures drain state swallowed chained swipes.** ✅ FIXED with #2 — re-planting
3 fingers over a straggler landed in `drain` and went nowhere; every second fast workspace
swipe died. `drain` now re-enters the gesture path on count ≥ 3.

**M14. `PAD_RES` was a placebo and its comment encoded a false model.** ✅ FIXED with #2 —
libinput gesture deltas never consult advertised resolution (the 136→60 "tuning" changed
nothing); the comment now documents the real mechanism and the real knobs (per-device
sensitivity/accel in `devices.lua`), and per-axis resolutions serve only the mm-based
classification heuristics.

---

## Live bugs (ali, 2026-08-06 evening) — all fixed

**B1. OSD flickered between the volume pill and the submap legend.** ✅ FIXED — they
shared the single `Osd.kind` slot, so Pipewire event bursts and submap events overwrote
each other, and after autoHide the legend was gone while the submap still had the
keyboard rebound. The submap indicator is sustained state now; the panel derives what to
draw (`OsdPanel.showing`): a transient value wins for its 1.5 s, then the legend takes
the spot back.

**B2. Opening Settings left the Control Center popout hanging.** ✅ FIXED — Popouts
closes itself whenever `SettingsUi.open` goes true (any route: gear row or IPC), the same
pattern it already used for capture starts.

**B3. 4-finger move dragged the FOCUSED window, not the one under the fingers.** ✅ FIXED
— Hyprland's move gesture has trackpad semantics (fingers have no position); the bridge
now focuses the window under the contact centroid at 4-finger start
(`hl.dsp.focus({ window = "address:…" })`, floating-over-tiled + most-recently-focused as
the topmost heuristic), blocking ~30 ms before the first pad push so the focus always
lands before the compositor's move-begin. Rotation-aware via the same transform mapping.

**B4. Touch-scrolling the launcher yanked the selection along.** ✅ FIXED — hover-select
is disabled in touch mode entirely (touch has no hover; taps activate their own row and
OSK Enter uses the keyboard selection) and suppressed while the list is dragging/moving
for the docked-touchscreen case.

**B5. Device-type gating audit (ali: "nothing may mess with the ASUS laptop").** ✅ FIXED
— most of the stack was already scoped (touch-gestures autostart, the Super+Ctrl+O/T/R
binds and the pad calibration rules are k3v1n-only or name-scoped; edge swipes, bar
buttons, touch floors and touch scale all key off `touchActive`), but three holes would
have bitten a laptop on its next pull: (1) hardware-auto tablet resolution had **no
touchscreen requirement** — an internal keyboard hiding behind tablet-sensors' phantom
filter (the AT-Translated node is a real keyboard on a real laptop) or a bogus WMI
SW_TABLET_MODE would have flipped the whole shell into touch mode; (2) `osk-focus-watch`
ran wherever `osk ≠ off` and held the seat's one input-method slot on machines that can
never tap an OSK; (3) `Displays.setTransform` wrote global touch/tablet calibration
matrices for any `eDP` panel — h4l9000's panel is also eDP-1. All three now gate on
`Tablet.hasTouchscreen` (a direct-multitouch device reported by tablet-sensors, rescanned
on udev events); explicit overrides (`tabletMode: "tablet"`, `osk: "on"`) stay honored.
Verified live on k3v1n (`hasTouchscreen: true`, gates pass); on a touchscreen-less host
the same code reports false and auto always resolves to Desktop — the Settings window's
Tablet section says so in words.

---

## Low

**L1. Fast flicks lose their first segment.** ✅ FIXED — the pending window keeps its FIRST contact set as the anchor (growing only when fingers land), pushes it on release, then streams live; verified in the state-machine harness (anchor at landing, staggered 2-finger taps stay 2-finger). `touch-gestures` pending→clone forwards only
the final snapshot: the touch-down anchor lands 50–180 px along the path at flick speeds,
and a 2→1→0 collapse inside the holdback delivers as a one-finger tap. Fix: anchor on the
_first_ pending snapshot, then stream live (don't replay the whole buffer — near-identical
timestamps spike kinetic-scroll estimators).

**L2. osk-float-rescue never restores clients that renegotiate geometry.** ✅ FIXED — 16 px tolerance compare, a blocking flock serialising reserve/restore, and state cleared only after the restore batch dispatched. Exact-equality
guard against the _commanded_ geometry treats a terminal that snapped to cell increments
as user-moved — stays lifted/shortened forever. Also reserve/restore can interleave (both
detached off one 90 ms timer). Fix: tolerance compare + flock on the state file + only
clear state after the restore batch dispatches.

**L3. osk-focus-watch's startup seed can clobber a real activate.** ✅ FIXED — seed skipped when the bind roundtrip already delivered focus; the v3 no-replay residual is documented in place. The unconditional
`{"focus": false}` seed is emitted _after_ the bind roundtrip that (for text-input-v1
clients) may already have delivered focus:true. Fix: skip the seed when focus is already
known. (Residual: Hyprland 0.56.2 doesn't replay activate to a newly-bound IME for an
already-focused v3 field — unfixable helper-side, document the tap-out-tap-in.)

**L4. tablet-sensors: a dead udev subprocess silently ends dock detection.** ✅ FIXED — udev EOF is fatal now; Tablet.qml's watchdog restarts the helper and startup re-derives everything. Dead sources
are removed, never respawned, and the process stays alive on the switch fd — so
`Tablet.qml`'s restart watchdog never fires. Fix: treat udev EOF as fatal so the 3 s
restart re-derives everything.

**L5. Any HID claiming Q/A/Z/Space counts as a keyboard.** ✅ Documented in place — extend PHANTOM_KEYBOARDS as receivers are met; the pointer-sibling heuristic is explicitly ruled out (the real magnetic keyboard is itself a keyboard+touchpad combo and would be filtered with them). Wireless-mouse receivers
(Unifying/Bolt) enumerate keyboard interfaces with a full key range — plugging a mouse
dongle into the undocked tablet kills touch mode and the OSK. Fix: extend the phantom
list as met, or check for a pointer sibling on the same USB parent.

**L6. touch-gestures lifecycle: one-shot grab, no single-instance lock, silent uinput
write drops.** ✅ FIXED (grab retried every 2 s while idle; flock in XDG_RUNTIME_DIR —
verified: a second launch refuses and exits). The silent-write-drop resync is the one
part deliberately skipped: partial-write recovery would guess at kernel state. A transient grabber at start permanently disables gestures ("passthrough
only" forever); a debug launch beside the autostart one creates ghost device pairs. Fix:
retry grab on the idle tick, flock in `$XDG_RUNTIME_DIR`, resync sink state on failed
contact-end writes.

**L7. theme-sync.sh: no serialization, non-atomic VS Code write, all-or-nothing `set -e`
— and Hyprland borders never follow the theme.** ✅ FIXED (flock so the last pick wins;
temp+rename for Code's settings.json; gsettings failures degrade alone). The
theme-following Hyprland borders remain a feature idea, not a fix. Rapid theme flips can desync targets or
briefly truncate Code's settings.json; `theme.lua` stays Rose Pine Dawn under all 15
other themes. Fix: flock; temp-file+mv; per-target isolation; optional
`hyprctl -r eval` border stage.

**L8. Binds target apps that don't exist on k3v1n.** ✅ FIXED — Discord and AudioRelay
moved to hosts/h4l9000.lua; the Super+z backlight pair is gone from k3v1n (no LED
exists); verified live: no MS+D/MS+A binds registered here. `MS+D` discord (h4l9000-only
package), `MS+A` AudioRelay (path absent), `Super+z`/`MS+z` kb-backlight → asusctl
fallback on a Minisforum with no kbd LED. Fix: move/gate per host; drop the z binds here.

**L9. External rotation leaves the rotate button stale.** ✅ FIXED — Displays.qml watches
every screen's logical geometry (quarter-turns refresh the cache immediately); the
180°/flip residual is documented and still self-heals via settle. `wlr-randr` by hand is invisible
to `Displays.qml` (no Hyprland event, poll only while the Display page is open) — first
bar-button tap after it is a no-op (self-heals after one tap). Now also means the
calibration matrices lag until the next qshell-driven rotate. Fix if it ever bites: watch
`Quickshell.screens` width/height for quarter-turns + slow background poll.

**L11. Launcher action rows execute stale captured objects.** ✅ FIXED — run() re-resolves
the entry by id and the action by name at press time, the appRow idiom. The app-row staleness fix
(re-resolve by id at press time) was never applied to the "▸ action" rows — a pacman
transaction while the launcher shows them makes Enter a silent no-op. Fix: capture
`entry.id` + `action.name`, re-resolve in `run()`.

**L12. `Settings.onLoadFailed` writes defaults over settings.json on _any_ failure.**
✅ FIXED with M7 (guarded on `FileViewError.FileNotFound`, matching Apps.qml).
`Apps.qml` guards the same pattern on `FileNotFound` specifically ("must not let the next
write clobber data"); Settings doesn't — a transient read error mid-hand-edit reverts the
edit. Fix: match the Apps.qml guard.

**L13. One transient helper error permanently latches `imGaveUp`.** ✅ FIXED — the helper
marks its three genuine give-ups `terminal: true`; the shell latches only on that, and
the latch now releases the input-method slot immediately. `Osk.qml` treats every
`available:false` line as terminal, but the helper also emits it for retryable errors —
after which the _next_ real exit is never restarted and focus-following silently degrades.
Fix: a `terminal: true` flag on the helper's genuine give-up paths; latch only on it.

**L14. OSK chords with € £ ° … silently do nothing.** ✅ FIXED — EuroSign/sterling/degree/
ellipsis added to the keysym map. The `-k` path passes the raw
character to wtype, which needs keysym names (`EuroSign`, `sterling`, `degree`,
`ellipsis`). Four keysym-map entries fix it. (The "eighteen-case harness" todo-tablet.md
cites isn't in the repo — worth committing.)

**L15. Clipboard picker's filter chips clip away in portrait.** ✅ FIXED — the chips row
is a horizontal Flickable, interactive only when it overflows. Fixed-width search box +
`clip: true` chips row: Images/Files/Colors unreachable by touch at 960 logical width.
Fix: make the chips row a conditional horizontal Flickable (the Popouts pattern).

**L16. Launcher width is never clamped to the screen.** ✅ FIXED — panel width clamps to
the output like every height already did. Portrait + touchScale ≥ ~1.3 puts
both edges off-screen (heights are all carefully clamped; width never was; OsdPanel
already has the precedent). Fix: `Math.min(launcherWidth, screen.width − s(24))`.

**L17. Remaining sub-floor touch targets.** ✅ FIXED — Bluetooth Badge bleeds its hit
area to the floor (a miss no longer navigates), PageHeader's back target and the
launcher help button floored, the Settings window's ChoiceRow segments fill the full
floor. The Bluetooth toggle Badge (39 px, and its
miss-area _navigates_), ChoiceRow segments (36 px tall), launcher help button, PageHeader
back target (the only way out of a Control Center page). Fix: floor them like the rest of
the audit did.

**L18. capslock_mode GUI toggles are inert on k3v1n.** ✅ FIXED — dual-generation guards
(legacy boolean OR capslock_mode string) at all four modmap sites. New Toshy GUI writes
`capslock_mode`; the tracked config reads only the legacy booleans (getattr → False
forever). h4l9000 works, k3v1n silently doesn't. Fix: dual-generation guard (legacy
boolean OR capslock_mode string).

**L19. Deprecated `to_US_keystrokes`/`unicode_keystrokes` aliases.** ✅ FIXED — try the
new names, fall back for h4l9000's older xwaykeyz; the config no longer dies the day
upstream removes them. Removal scheduled
"any time after mid-2027"; the config uses them at :412-413 (ST ×13, UC ×762 via macros) —
when they go, the whole config fails to load and the service flaps. Fix: switch to
`str_to_keystrokes`/`unicode_addr_to_keystrokes` now.

**L20. Touchscreen clone advertised Y res = X res.** ✅ FIXED with #2 — real per-axis
resolutions are now copied from the digitiser (was claiming a 303×303 mm panel; harmless
for taps — positioning is range-normalized — but a trap for any mm-based consumer).

---

## Nits

**N1. Session-plumbing stale comments and dead code.** ✅ FIXED — toggle-edp.sh's dead
loader + h4l9000 constants removed, apps.lua M.bg removed, the no-op Razer device
entries removed, eww/ags/CurseForge/lutris floats trimmed (steam/bottles/VirtualBox
kept for the other hosts). Original: `options.lua:57-60` "there is no
runtime eval" (false, and it's what froze vfr globally — fix with H8);
`toggle-edp.sh`'s never-called `load_monitor_state()` with h4l9000 constants; `apps.lua`
`M.bg` pointing at a nonexistent wallpaper with no consumer; empty razer entries in
`devices.lua`; stale float rules (trim eww/ags/CurseForge/lutris; keep steam/bottles/
VirtualBox for the other hosts).

**N2. Leftover upstream Toshy entries.** ✅ FIXED — the dialog Cmd+W fix emits Super-Q
(was dead Alt+F4), Right-Win+Tab passes through to the overview (was swallowed), the
shadowed VSCodes arrow rows are annotated, the ALT+Tab comment in binds.lua now tells
the true mechanism, and the power submap's entry bind moved into binds.lua with a label
— it is in the Super+/ cheatsheet now, reading (r)eboot. Original: The dialog Cmd+W fix emits Alt+F4 (dead here —
retarget to Super-Q); General GUI's `Alt-Tab: ignore_combo` swallows physical
Right-Win+Tab; two shadowed VSCodes arrow entries can never fire. Also `binds.lua:30-32`'s
ALT+Tab comment is wrong on both claims (the bind works _because of_ the keymap it says
doesn't exist — don't let anyone "simplify" General GUI's RC-Tab entry), and
`k3v1n.lua:80-85` still contradicts the gesture bridge shipped in the same file.
(Cheatsheet gaps ride along: the power submap is invisible to Super+/, and its label says
"(r)eset" where the key reboots.)

**N3. qshell services nits.** ✅ FIXED — exeByPid capped at 256 with wholesale reset, the
submap-hints mirror carries a loud drift warning, both plain-argv sh -c wrappers
dropped. Original: Unbounded `exeByPid` cache (recycled pids get stale icons);
`Osd.qml` hand-mirrors submap key hints (drifts silently when submaps change); two
needless `sh -c` wrappers on plain argv spawns.

**N4. qshell UI nits.** ✅ FIXED — todo-tablet's barSlop/bar-height claims corrected,
kdectest writes to plain /tmp, DisplayPage appends the orientation label when rotated,
CtlButton's property is `armed`. Original: todo-tablet.md claims "barSlop doubles" (it doesn't) and that the
48 px floor covers "bar height" (Appearance explicitly declines); `shell.qml:289`
`kdectest()` writes into a hardcoded Claude-session temp dir; DisplayPage prints the
untransformed mode with no orientation hint; `CtlButton` shadows `Item.enabled`.

**N5. Toshy README polish.** ✅ FIXED — file-count wording, sqlite churn note, the
throttle_delays ~20 ms/keystroke note, and the tracked-vs-live systemd units warning are
all in config/toshy/README.md. Original: "two files" vs "three tracked files" contradiction; the
sqlite churn note misses schema-migration rewrites; throttle*delays' ~20 ms/keystroke cost
(≈40–80 ms for multi-combo macros like yazi's Cmd+T) undocumented; note that the tracked
systemd units are \_not* what systemd runs (Toshy's installer writes its own).

---

## Verification method note

Every finding above survived an adversarial re-check: a second agent re-opened each cited
file:line, re-ran the read-only commands, and re-derived the arithmetic; 14 findings had
severity or fix corrected in that pass and 1 was refuted outright (an edge-swipe/bar
stacking claim whose failure scenario didn't survive geometry). The Hyprland claims were
verified against the source of the exact running commit; libinput claims against 1.31.3;
Toshy claims against the upstream base template (`17dc24c4c3`) the tracked config derives
from, and against both installed xwaykeyz generations (1.21/h4l9000, 1.25/k3v1n).
