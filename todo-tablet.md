# Tablet mode — k3v1n

Making the Hyprland + qshell desktop usable with only fingers on `k3v1n`
(`Micro Computer (HK) Tech Limited V3`, chassis type 32 = *Detachable*, AMD,
2560x1600@120 eDP-1, Goodix touch + stylus digitiser, magnetically attached USB
keyboard/touchpad).

Everything here is host-scoped. Nothing changes how `mcu` (desktop) or `h4l9000`
(laptop) behave — the shell decides at runtime from hardware state, and the
compositor bits live in `config/hypr/lua/hosts/k3v1n.lua`.

Status: **built and verified except where noted.** What is still unverified is
listed under "Left to confirm on hardware" at the bottom.

---

## Hardware survey

Run once, so nobody has to re-derive it:

| Thing | Present? | How it shows up |
| --- | --- | --- |
| Touchscreen | ✅ | `PNP0C50:00 222A:550D`, libinput cap `touch` |
| Stylus | ✅ | `… 222A:550D Stylus`, cap `tablet`, 303×190mm |
| Detachable keyboard | ✅ | USB `05af:326a Jing-Mold`; leaves `/proc/bus/input/devices` when detached |
| Tablet-mode switch | ✅ | `gpio-keys` `/dev/input/event15`, `SW=2` → `SW_TABLET_MODE`; readable by the seat user via its `uaccess` ACL |
| Ambient light sensor | ✅ | `iio:device0` = `als`, HID sensor usage `0x41` |
| **Accelerometer** | ❌ | **see below** |
| Gyroscope / compass | ❌ | same |

### Autorotate: the hardware cannot do it

`monitor-sensor` reports `=== No accelerometer`. That is not a driver gap a
quirk fixes — the AMD Sensor Fusion Hub's HID report descriptor
(`/sys/bus/hid/devices/0020:1022:0001.0004/report_descriptor`, 364 bytes)
declares exactly one sensor collection on usage page `0x20`:

```
sensor usages: 0x41 (ambient light) + its properties/data fields
```

No `0x73` (Accelerometer 3D), no `0x76` (Gyrometer), no `0x83` (Compass), no
`0x8A` (Device Orientation). The firmware exposes an ALS and nothing else, so
there is no rotation signal to read, from any daemon, at any privilege level.

**What shipped instead:** rotation is a *manual* control (bar button, Control
Center card, `Super+Ctrl+R`) with a rotation lock — and the autorotate path is
written and wired anyway. `bin/tablet-sensors` subscribes to `monitor-sensor`,
reports whether an accelerometer exists at all, and `services/Tablet.qml`
maps orientation → transform with the same mapping mutter uses. It is inert on
this panel and starts working the day a sensor exists. **Don't delete it as
dead code.** The Control Center reads `Tablet.hasAccelerometer` and says so out
loud rather than hardcoding this machine's answer into a label.

### Runtime output changes must go through `wlr-randr`

`hyprctl keyword …` answers **`keyword can't work with non-legacy parsers. Use
eval.`** here, because the config is the Lua parser (`config/hypr/hyprland.lua`).
Hyprland does implement `zwlr_output_management_v1`, so `wlr-randr` is the
working path for rotation and for enable/disable.

### Gestures are trackpad-only — but `action` takes a callback

`hl.gesture(…)` builds `CTrackpadGesture` objects; directions are
`horizontal`/`vertical`/`swipe`/`pinch`/`pinchin`/`pinchout`, with no edge
origin and no touchscreen equivalent beyond the legacy
`gestures:workspace_swipe_touch` (already `true`).

A comment in `binds.lua` claimed `hl.gesture` "only supports built-in actions …
not exec". **That half was wrong.** `action` also accepts a table of Lua
callbacks (`start` / `update` / `end` / `finish`) — verified by adding one and
getting a clean `hyprctl configerrors`. The comment is corrected and the new
3-finger-vertical → overview gesture is the counter-example.

---

## What was built

### 1. Compositor scale → 166% ✔

`config/hypr/lua/hosts/k3v1n.lua`: eDP-1 `scale` 1.333334 → **1.666667**.
2560 × 3/5 = 1536 and 1600 × 3/5 = 960, both exact, so Hyprland takes the
fraction as given. Logical desktop is now 1536×960 (confirmed live).

### 2. Tablet detection — `bin/tablet-sensors` + `services/Tablet.qml` ✔

One long-lived helper emitting JSON lines, rather than three pollers in QML,
because every fact has a real event source:

- **keyboard attached** — scans `/proc/bus/input/devices` for devices that claim
  Q/A/Z/Space (which excludes the power button, lid, WMI hotkeys, rfkill and
  consumer-control nodes that the kernel also calls keyboards), minus a phantom
  list for `AT Translated Set 2 keyboard` (the i8042 stub, present on a chassis
  with no built-in keyboard) and `XWayKeyz` (Toshy's own uinput device, which is
  downstream of the real keyboard and outlives it). Re-scanned on
  `udevadm monitor` events, debounced — edge-triggered, not polled.
  *Verified:* on this machine the filter selects exactly one device, `USB Keyboard`.
- **tablet-mode switch** — `EVIOCGSW` for the initial state, then `select()` on
  the `gpio-keys` node. *Verified:* node auto-discovered as `/dev/input/event15`.
- **accelerometer + orientation** — `monitor-sensor` stdout.

*Verified live:* `qs -c qshell ipc call tablet status` →
`{"mode":"auto","tablet":false,"keyboardAttached":true,"tabletSwitch":false,`
`"orientation":"normal","hasAccelerometer":false,"ready":true}`

The resolved answer is published to `Settings.touchActive`, which is the single
flag everything visual reads. It is routed through `Settings` and not straight
into `Appearance` because `qs.config` must not import `qs.services`.

### 3. On-screen keyboard — `modules/osk/` + `services/Osk.qml` ✔

**`osk: auto` follows text focus**, not just the keyboard. It stays down until
you tap into something typable and drops when focus leaves, which is what stops
it permanently eating a third of a 960px-tall screen. Both halves of the gate
matter: keyboard-only left it up for the whole undocked session, and focus-only
would raise a keyboard on a docked desktop every time you clicked an address
bar — the exact behaviour squeekboard was removed for.

Focus comes from `bin/osk-focus-watch`, because there is no other source for it:
Hyprland's IPC has no IME event (checked the whole event list) and Quickshell has
no input-method API, so the only place the fact exists is the Wayland protocol —
apps speak `zwp_text_input_v3`, the compositor relays to whoever holds
`zwp_input_method_v2`, and holding that means being a Wayland client. The helper
binds as that input method and reports `activate`/`deactivate` plus the field's
`content_type`. It never grabs the keyboard and never commits text: a listener
wearing an input method's hat.

Three things worth knowing:

- **The protocol XML is vendored** at
  `system/wayland-protocols/input-method-unstable-v2.xml`. No Arch package
  ships it (`wlr-protocols` does not; `pywayland` bundles v1 only), so it is
  fetched once and committed, and scanned into Python bindings on first run
  into `~/.cache/qshell/pywl`.
- **A seat has room for one input method.** While this runs, fcitx5/ibus cannot
  bind; if one is already bound the helper gets `unavailable`, says so, and
  exits rather than fighting. It only runs while `osk` is not `off`, so
  switching the keyboard off hands the slot back.
- **The shell's own panels are a special case.** Qt does not drive
  `zwp_text_input_v3` from a layer surface — verified by watching the protocol
  with the launcher's field focused and getting nothing — so the launcher and
  clipboard picker are treated as text focus explicitly. Without that, the one
  place a tablet most needs a keyboard would be the one place it never appeared.

If the watcher is not running, focus is simply unknown and `auto` falls back to
always-up-while-undocked. A keyboard that is up too often is a nuisance; one
that never appears is a machine you cannot type on.

- Bottom layer surface, `WlrKeyboardFocus.None` (a keyboard that takes focus
  takes it away from the thing you are typing into).
- **`exclusiveZone` = its height** — the whole "shrink the windows" requirement,
  in one property. *Verified live:* toggling it moved the monitor's reserved
  bottom `0 → 307` and both tiled windows `897 → 590` high, and back again on
  hide.
- **Floating windows** are exempt from that by definition, so
  `bin/osk-float-rescue` lifts (and shortens, if they cannot fit) the ones that
  would be cut, and restores them after — but only if they are still exactly
  where it left them, so a window you placed yourself while typing keeps your
  geometry. *Verified* against synthetic `hyprctl` data covering lift, shrink,
  ignore-tiled, ignore-other-workspace, and moved-since-restore.
- **Key injection via `wtype`** (`zwp_virtual_keyboard_v1`), deliberately not
  `ydotool`: uinput injection lands *below* libinput and therefore below Toshy,
  which remaps this keyboard into a macOS layout — an OSK on that path would
  have its own output remapped on the way back in. wtype enters at the
  compositor and Toshy never sees it.
- Two layers (letters / symbols), one-shot modifiers that lock on a second tap,
  hold-to-repeat on backspace and the arrows.
- Auto-shown only when no physical keyboard is attached; `Settings.osk` is
  `auto`/`on`/`off`, and a bar button overrides until the hardware changes.

The utility row is labelled `esc tab ctrl alt super` in **words, not glyphs** —
Framework7's `escape` reads as "undo" at cap size, and ⌥/⌘ would name the macOS
layout that this keyboard is the one thing that does *not* go through.

### 4. Touch mode — bigger everything ✔

`Settings.touchScale` (default 1.25) multiplies into `Appearance.scale`, so
every `s()` call site in the shell grows with no edits — *audited:* no tappable
component in `modules/` or `components/` has a hardcoded pixel size, so the
multiplier reaches all of it. On top of that, `Appearance.touchTarget` is a
48-logical-pixel floor (~9.5 mm at this panel's DPI, and deliberately *not*
`s()`-scaled, since a finger does not grow with the scale slider) applied to the
menu rows, launcher rows and the new chips (deliberately NOT the bar height —
Appearance.qml explains why the bar stays thin; `barSlop` does not change in
touch mode either — an earlier version of this line claimed both).

### 5. Rotation ✔

`wlr-randr`-backed in `services/Displays.qml`: four transform chips on the
Display page, a bar button that cycles (right-click resets), `Super+Ctrl+R`, and
a rotation lock that gates the accelerometer path. ~~Touch coordinates follow
the output transform automatically because `input:touchdevice:output = eDP-1`
is already set.~~ **That claim was false** (2026-08-06 review): output-pinning
only selects the mapping box; Hyprland 0.56 never rotates touch/stylus coords.
Fixed since: `Displays.qml` writes the `input:touchdevice:transform` /
`input:tablet:transform` calibration matrices via `hyprctl -r eval` when
rotating eDP, and `bin/touch-gestures` counter-rotates its gesture pads by
watching `wl_output`. See desktop-review.md, Top 3 #1.

### 6. Touchscreen edge swipes — `modules/gestures/` ✔

Three 8px layer strips, active only in touch mode: bottom ↑ launcher, left →
overview, right ← Control Center. Top edge is left to the bar. *Verified:* the
strips are absent from `hyprctl layers` while docked, which is correct.

### 6b. Multi-finger gestures on the touchscreen — `bin/touch-gestures` ✔

The compositor cannot do this: `hl.gesture(...)` builds *CTrackpadGesture*
objects and the only touch gesture Hyprland implements at all is
`gestures:workspace_swipe_touch`. So the digitiser is read directly
(`/dev/input/event10`, type-B multitouch, `uaccess` ACL — no root) and the same
three gestures are dispatched:

| | touchpad (compositor) | touchscreen (this) |
| --- | --- | --- |
| 3 fingers ←/→ | workspace | `workspace e±1` |
| 3 fingers ↑/↓ | overview | overview |
| 4 fingers | interactive `move` | `movetoworkspace e±1` |

The 4-finger difference cannot be closed: the touchpad's action is Hyprland's
interactive drag, which from outside the compositor would mean streaming
`movewindowpixel` at touch-event rate, and means nothing for a tiled window
anyway. Moving the window to the adjacent workspace and following it is the
thing you actually want a window moved *for*.

Decisions are made on the **average** travel of the contacts, which is what
makes it a swipe rather than N drags — three fingers splaying apart average to
zero and are correctly ignored as a pinch. *Verified* against twelve synthetic
event sequences: each direction at 3 and 4 fingers, 1/2/5-finger contacts
ignored, sub-threshold movement ignored, splay ignored, and exactly one fire per
gesture.

**One wart, by necessity:** it reads the device passively rather than
`EVIOCGRAB`-ing it, because grabbing would take touch away from every
application. So a recognised gesture's contacts are *also* delivered to whatever
is underneath. Most toolkits track at most two contacts so this is quiet in
practice, but a canvas app that handles many will see them, and they cannot be
un-sent from here.

### 7. Trackpad gestures ✔

`hyprctl configerrors` is clean, so all three are accepted:

```lua
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })  -- asked for
hl.gesture({ fingers = 4, direction = "swipe",      action = "move" })       -- asked for
hl.gesture({ fingers = 3, direction = "vertical",   action = { finish = … } })  -- new: overview
```

### 8. Packaging ✔

`wtype`, `wlr-randr` and `iio-sensor-proxy` added to
`profiles/k3v1n-arch/packages/pacman.txt` (the first two were installed by hand
during this work; a fresh provision now gets them).

---

## Review round (2026-08-06): 13 confirmed findings, all fixed

A four-dimension adversarial review (services / surfaces / helpers / touch-UX,
each finding re-verified by a skeptic against the code) plus live testing on
the running shell. What it caught, worst first:

- **`hyprctl dispatch` with classic strings is refused under the Lua parser** —
  args are pasted verbatim into `hl.dispatch(...)`, a Lua syntax error. Both
  `bin/touch-gestures` and `bin/osk-float-rescue` were built on it and were
  dead on arrival; the unit tests stubbed `dispatch()` so they verified the
  state machines and never the IPC form. Both now emit Lua dispatcher
  expressions (`hl.dsp.window.move({ window = "address:…", x, y })`), the same
  form Overview.qml already used. Verified live: the full rescue cycle
  (300 → 141 → 300) and a float spawned under the open keyboard auto-lifting.
  Bonus discovery: `window.resize` anchors at the window's *centre*, so rescue
  always follows a resize with an exact move.
- **Typing on the OSK closed the panel being typed into.** Every
  `HyprlandFocusGrab` (launcher, clipboard, popouts) whitelists only its own
  windows, and a tap anywhere else clears the grab — so the first key tapped
  on the keyboard dismissed the launcher. The OSK's window is now published
  (`Osk.panelWindow`) and whitelisted in all three grabs.
- **The Control Center's own text fields never raised the keyboard** (and
  opening the panel actively *lowered* it, since the popout's grab drops the
  app's text-input focus). Popouts now publish `Osd.popoutTextFocus` from
  `Window.activeFocusItem` (duck-typed on `cursorPosition`), and the OSK
  treats it as text focus — same reasoning as the launcher/clipboard flags.
- **Slider drags were stolen mid-drag by the popout's Flickable** — a finger
  wobbling a few px vertically handed the grab to the list, freezing the value
  wherever the steal happened (for the scale sliders: the whole shell resized
  to an accident). `preventStealing: true` plus a touch-floor hit strip on
  StyledSlider.
- **`qs ipc call osk show` never reached the handler** — `show` is a real
  `qs ipc` subcommand; the CLI printed the target listing and exited 0.
  Renamed to `open`/`close` (the launcher's convention, which works).
- **Touch floors across the Control Center**: StyledSwitch's ~30px hit strip
  bled out to the 48px floor and its whole row now toggles; stepper ± buttons
  floored fully (an undersized miss landed on the *neighbouring* stepper);
  Home's sound row, mute/mic buttons, media buttons and the Disclosure chevron
  (the only route into the audio page) floored.
- **Double-tap rotate lost the second tap** — `rotate()` derived the next
  quarter-turn from a cache that only refreshed ~900ms later (a transform
  change emits no Hyprland event), so a quick 180° flip landed at 90°. The
  cache is now written optimistically; settle reconciles.
- **`touch-gestures` died permanently on a digitiser read error** (i2c-hid
  nodes reset on suspend/resume) — now supervised: re-finds the node and
  reopens with backoff, since its event number can change across resets.
- **Float rescue skipped floats on invisible workspaces** and nothing re-ran
  it on workspace switch — in pinned-on mode a dialog on workspace 3 stayed
  behind the keyboard forever. The sweep is monitor-wide now, and
  `openwindow`/`movewindow`/`changefloatingmode`/`workspace` events re-trigger
  it while the keyboard is up.
- **`workspaces`/`overviewColumns` unclamped on the read path** — a hand-edit
  of the live-reloaded settings.json reached Overview as a division by zero.
  Clamped like the other numerics.
- **`osk-focus-watch` violated the protocol's activate-resets-state rule** —
  a field that never sends `content_type` inherited the previous field's
  purpose (tab from a password box to a plain entry: still "password").
- **The OSK bar button was visible-but-inert with `osk: off`** — hidden now;
  a control that visibly does nothing is worse than its absence.
- Refuted by the skeptics (left alone, correctly): the `setEnabled`
  stale-guard claim, a tablet-sensors pipe-buffering claim, an edge-swipe
  reopen claim, and two findings against code already fixed mid-review.

Also from this round: the Quickshell file watcher can wedge after a failed
reload — `touch qshell/shell.qml` re-triggers it (edits to `services/*`
singletons alone don't always).

## Round three (2026-08-06): theme sync + real window gestures

### Theme sync — one theme, everywhere

`scripts/theme-sync.sh`, driven by `services/ThemeSync.qml` on every theme
change (the launcher's `#` picker, `qs ipc call theme set`, or a hand edit of
settings.json — all the same signal). What each target does with it:

| Target | Mechanism | Live? |
| --- | --- | --- |
| kitty | `current-theme.conf` include + SIGUSR1 | yes, open windows recolor |
| GTK4 / libadwaita | gsettings `color-scheme` via portal | yes |
| GTK3 | `adw-gtk3` ⇄ `adw-gtk3-dark` + settings.ini mirror | next launch |
| Chrome | watches the portal color-scheme | yes |
| VS Code | `workbench.colorTheme` in settings.json | yes, Code watches the file |
| ghostty | theme line + SIGUSR2 | **unverified — not installed**; names are best-guess |

All 16 shell themes have kitty palettes now (14 generated from the official
upstream ports into `config/kitty/themes/`). VS Code theme names are exact —
read from the installed extensions' `package.json`, with the missing families
installed (`catppuccin-vsc`, `tokyo-night`, `gruvbox`, `nord`, `dracula`,
`everforest`, `kanagawa`; `rose-pine` was already there). Round-tripped live
through the shell: rose-pine out, catppuccin-latte back, every target
following.

### Touchscreen gestures — `bin/touch-gestures` v3, the touchpad bridge

Established by injection (a virtual uinput touchscreen, since fingers can't be
scripted): Hyprland 0.56 has **no** native touch gesture support at all — the
legacy `workspace_swipe_touch` does nothing under the new gesture system, an
`hl.gesture` `mode = "touch"` field parses but is inert, touch does not feed
mousebinds, and the Lua runtime has no swipe-progress API (enumerated).

v2 interpreted gestures itself and issued discrete dispatches — which felt
like jump cuts, not the trackpad. **v3 stops interpreting and starts
routing**: it grabs the digitiser and splits the stream between two virtual
devices —

- `qshell-touch-screen`, a touchscreen clone: 1-2 finger input passes through
  untouched (apps, the OSK, the edge strips all unaffected — verified: a tap
  through the router still focuses the window under it);
- `qshell-touch-pad`, a virtual **touchpad**: 3/4-finger contact sets are
  replayed here, libinput classifies it as a gesture-capable touchpad
  (confirmed: `pointer gesture` capabilities), and Hyprland runs the *same*
  CWorkspaceSwipeGesture / CMoveTrackpadGesture / Lua-callback machinery the
  physical trackpad uses. `hl.gesture` bindings now simply apply to the
  touchscreen; 1:1 follow, animation, snap-back, direction and the
  swipe-distance settings are the compositor's own.

Verified by injection: 3-finger swipes work in both directions and repeat
reliably; a swipe releases mid-way and snaps back exactly like the trackpad;
the 4-finger drag over a **tiled** window runs Hyprland's real interactive
move (the tiles visibly swap — impossible with any dispatch). Long drags
clamp at one workspace per gesture because `workspace_swipe_forever` is off —
one setting, applies to trackpad and touchscreen equally.

Two hard-won implementation notes:

- **Kernel evdev deduplicates ABS values per slot.** A finger landing where
  the previous contact ended produces *no* position event for that axis; the
  reader must keep slot coordinates across contacts, like the kernel does.
  Wiping them on lift-off made the router go silent after the first gesture —
  found because injected gestures reuse coordinates deterministically.
- New contacts are held back ~35ms while the finger count settles, so the
  first two fingers of a 3-finger swipe can't fire a stray tap into the app
  underneath. If the daemon dies mid-grab, the kernel drops the grab with the
  fd and the supervise loop reopens everything.

Super+touch move/resize existed briefly (v2, fully verified) and was rolled
back at the user's request to be rethought; the implementation is in git
history.

## Bugs found and fixed along the way

- **`RotateStatus.qml` shadowed `Item.transform`, which is FINAL.** This one
  took the shell down: `Cannot override FINAL property` → `Type RotateStatus
  unavailable` → `Type Bar unavailable` → crash loop into systemd's
  `start-limit-hit`. Renamed to `turn`, and the same trap avoided in
  `DisplayPage`'s `TurnChip` (`to`). *Lesson: `Item` already owns `transform`,
  `scale`, `rotation`, `state`, `data`, `children` — don't name a property after
  one.*
- **`Ctrl+Shift+V` went out double-shifted.** The chord builder used the
  *shifted* character for the keysym while also holding Shift, so it asked
  libxkbcommon for `V` (= shift+v) with shift already down. Now the modifier
  path uses the unshifted base character. All eighteen chord cases are dumped
  and checked by a harness.
- **`Displays.setEnabled()` had never worked.** It disabled outputs with
  `hyprctl keyword monitor <name>,disable`, which this config's parser refuses.
  Ported to `wlr-randr --output X --off`.
- **The OSK backdrop was 3% transparent**, inherited from the theme's
  `surfaceBg`. Fine for a launcher you glance at; measurably wrong for a dense
  grid of low-contrast caps you stare at — a screenshot over a cookie banner had
  ghost text *inside* the keys. Forced opaque.
- **The space bar was invisible.** Treated as a "special" (recessed) key, it
  rendered the same RGB as the panel behind it — the most-hit key on the
  keyboard was the only one with no visible edges. It gets the character-key
  tint now.
- **Every popout menu was taller than the screen.** The surface was a flat
  `s(920)`, which is 1058px at this machine's scale on a 960px-tall screen — it
  hung 137px off the bottom, and content past the edge was silently *clipped*,
  rows simply not drawn (a limitation `Popouts.qml`'s own comment documented for
  the Wi-Fi menu). Now capped to the room actually below the bar, minus the
  keyboard's reservation, with the content scrolling instead of clipping —
  `interactive` only when it overflows, so a menu that fits behaves exactly as
  before. Confirmed live: `qshell:popouts` went `1536x1058` → `1536x921`.
- **`bin/tablet-sensors` emitted its first line twice.** The startup line and
  the first committed `done` were the same state; the watcher is seeded to match
  so the first real change is the first change reported.

## Still open (pre-existing, not introduced here)

- [ ] `binds.lua` `Super+Ctrl+D` / `Super+Ctrl+S` set
      `xwayland:force_zero_scaling` through `hyprctl keyword`, which is refused
      under the Lua parser. They have been dead for as long as the Lua config
      has existed. Either drop them or find a runtime path that works.
- [ ] `lua/devices.lua` configures only desktop mice. If the digitiser ever
      needs per-device tuning (palm rejection, pressure curve) it goes there.

## Left to confirm on hardware

1. **Detaching the keyboard** — that touch mode comes on and the OSK follows
   focus. Force it meanwhile with `Super+Ctrl+T`, or
   `qs -c qshell ipc call tablet mode tablet`.
2. **The float rescue against a real floating window** (verified against
   synthetic `hyprctl` data, not a live one).
3. **Rotation** — `Super+Ctrl+R`. Untested live on purpose: it turns the screen
   you would need in order to undo it. `qs -c qshell ipc call display reset`
   puts it back.
4. **The gestures under real fingers** — the three edge swipes, and the
   3/4-finger touchscreen swipes (logic is unit-tested, thresholds are a feel
   judgement: 14% of the panel, in `bin/touch-gestures`).

Two debugging handles, because "the keyboard didn't appear" has six possible
causes:

```
qs -c qshell ipc call osk status      # every input to the show/hide decision
qs -c qshell ipc call tablet status   # keyboard, hinge switch, accelerometer
```

## Explicitly not doing

- **Sensor autorotate.** No accelerometer exists. The listener is written; the
  hardware is silent.
- **A system OSK (squeekboard/wvkbd).** `lua/hosts/k3v1n.lua` documents why
  squeekboard was removed — it put a keyboard on screen during a normal desktop
  session. The qshell OSK is gated on the keyboard actually being detached,
  which is the behaviour that was wanted the first time.
- **Long-press accent popups.** Considered, not built. The layouts cover a
  terminal and an editor, which is what this machine is for.
