# qshell

Desktop shell for Hyprland on h4l9000, built with [Quickshell](https://quickshell.org/)
(QML). Successor to the AGS prototype in the j4rv15 repo (`shell/`).

Transparent top bar drawn over the wallpaper — workspaces left, clock center,
tray / notifications / control center / battery / wifi right — plus a
[caelestia](https://github.com/caelestia-dots/shell)-style app launcher and
dropdown menus for every status module. Motion is caelestia's Material 3
expressive token set (curves + durations in `config/Appearance.qml`).

## Run

```sh
qs -c qshell
```

The source lives at the repo root (`dotfiles/qshell`).
`config/quickshell/qshell` is a relative symlink to it, so the standard
dotfiles convention (`~/.config/quickshell` → `dotfiles/config/quickshell`)
still resolves `qs -c qshell` without special-casing the installer.

Hyprland wiring (`~/.config/hypr/lua/`):

- `apps.lua` `M.bar` — started on session start (`startup.lua`), restarted with
  Super+Shift+C ("toggle bar" bind).
- `apps.lua` `M.menu` — Super+D toggles the launcher via IPC.
- `apps.lua` `M.clipboard` — Super+Shift+V toggles clipboard history via IPC
  (was a wofi pipe; the old command is kept commented out as a fallback).
- `rules.lua` — `qshell:.*` layer surfaces fade (content animates itself).


## Modules

- **Workspaces** — empty → hollow circle, populated → app icons (first 3),
  focused → a pill that slides *and stretches* between slots (leading edge
  fast, trailing at 2× duration, M3 emphasized — caelestia's ActiveIndicator
  turned horizontal). Urgent → red tint. Click focuses, scroll cycles. On the
  hyprland-lua config, dispatches go through `hl.dsp.*` (`Hyprland.usingLua`).
  Icons come from `Apps.toplevelIcon`: window class → desktop entry, and when
  that misses (`kitty --class=com.ali.floating_shell`) the pid's `/proc`
  argv[0] is looked up instead, so custom-class windows keep their real icon.
- **Tray** — collapsed behind an ellipsis, items slide out on hover. Leftward,
  because the status Row is right-anchored: growing left leaves the ellipsis
  and every icon after it in place instead of shoving the trigger out from
  under the cursor. Stays open while one of its own menus is. The ellipsis is
  drawn full-strength even when collapsed — it's the affordance for a whole
  hidden row, and a dimmed one read as a disabled control rather than "there's
  more over here"; the reveal is its own hover feedback.
- **Privacy lights** (`modules/bar/PrivacyStatus.qml`) — filled squircles with
  white glyphs, immediately left of the tray ellipsis, sized to the same height
  as the active workspace pill so both ends of the bar agree on how big a
  container is. Presence is the signal, so neither has an idle state: a **green
  camera** while a webcam is open, an **amber mic** while the mic is live (not
  muted). Clicking the mic mutes it, which also makes it disappear — the light
  is both the warning and the switch that clears it. Both fade and scale in,
  because appearing out of nowhere in the corner of a bar is easy to miss and a
  moving thing isn't.
  - Badges rather than bare glyphs because a coloured icon on transparent bar
    chrome is at the mercy of the wallpaper behind it, while a solid fill
    carries its own contrast and reads as a status light instead of one more
    clickable icon. Their fills (`Theme.privacyCam` / `privacyMic`) are
    deliberately **not** per-theme: these are safety indicators whose job is to
    be unmistakable — macOS keeps its camera/mic dots identical in light and
    dark for the same reason — and they have to carry a white glyph, which
    `barOk`/`barWarn` can't, being foreground tints that are pale pastels in
    mocha.
  - The mic tracks the **mute switch**, not whether something is currently
    capturing: the question it answers is whether anything *could* be
    listening, and what happens to be connected this second doesn't change the
    exposure.
  - The Sound page separately names **who** is listening (`Audio.micUsers`,
    from live PipeWire link groups on the source node), since a bar glyph can
    say that something is but not what.
  - Camera detection is `/sys/module/uvcvideo/refcnt` (`services/Camera.qml`):
    one 25µs read covers every UVC device at once — four here, the FHD webcam
    plus the IR one for face unlock — with no enumeration and no caring which
    is which. Polled at 700ms because there is no event: inotify doesn't fire
    for writes the kernel makes to its own attributes, and this file has no
    `sysfs_notify` behind it either (checked — POLLPRI never arrives). It counts
    *opens* rather than streaming, which is the right direction to err for a
    privacy light.
- **Popout menus** (click any status module — each icon opens its own menu in
  place under it; position and size snap, and it scales+fades in over 300ms on
  the M3 emphasized-decelerate curve, growing from its top edge so it reads as
  coming out of the bar. The host window's height is a constant, *not* derived
  from the panel: sizing the layer surface to its content made the surface
  resize on every open, and the `qshell:.*` layer rule animates that — a second,
  laggier grow underneath the real one. `modules/bar/popouts/`):
  - *Wi-Fi* — toggle, current-connection card (SSID, signal, v4 lease — read
    off the link, since NetworkDevice.address is the MAC), live scan while
    open with a manual refresh, connect (inline password field for secured
    networks), ethernet devices, Tailscale, VPN/WireGuard toggles (nmcli).
    Past 6 networks the list scrolls instead of growing the menu.
  - *Battery* — Power Saver / Balanced / Performance via power-profiles-daemon,
    charge estimate. Bar shows a drawn horizontal battery with the current CPU
    profile as a smaller glyph to its left (tortoise / gauge / hare), tinted
    green / white / amber — next to a battery reading, "which way is this
    costing me" is the thing you want at a glance. Names, glyphs and the
    profile list all come from `services/Power.qml`, because the bar badge, the
    menu and the OSD show the same thing and three private copies of
    "Performance is the hare" only agree by luck. Below that, the ROG
    platform knobs (`services/Asus.qml`): **fan profile**, **charge limit**
    (60/80/100) and **GPU mode**. The CPU governor and the ASUS platform/fan
    profile are genuinely different settings, so both are listed rather than
    collapsed into one. GPU mode changes never apply immediately — supergfxd
    reports a required logout/reboot, which shows inline *and* fires a
    notification, since the menu is usually shut by the time it decides.
    Two parsing traps, both hit: `asusctl profile get` prints four lines (the
    active profile plus separate AC and battery ones — only the first is in
    effect), and `supergfxctl -s` needs its brackets stripped *before* commas
    are turned into separators, or every mode concatenates into one string.
  - *Notifications* — DND toggle, clear-all, full history.
  - *Tray* — custom-drawn DBus menus (QsMenuOpener), one inline submenu level.
- **Control Center** (the `equal_square_fill` glyph, next to the bell — `modules/control/`)
  — a home screen plus drill-down pages, macOS Control Centre style. Home is
  only one-tap toggles and sliders; anything that needs a *list* (sound
  devices, Bluetooth pairing, KDE Connect actions) gets a row that pushes its
  own page, so the common case never leaves the first screen.
  - *Navigation* is an iOS-style push: home parallaxes left at a third of the
    speed while the page slides in from the right, and the panel morphs to the
    new height (320ms, M3 emphasized). Both screens live in one clipped Item —
    two x offsets and an opacity, no window resize, because the `qshell:.*`
    layer rule would animate a resize underneath. The height Behavior stays
    *disabled until the first navigation*: the opening layout pass arrives at
    home's height from zero, and animating that plays a grow on every open.
  - *Connectivity card* — Bluetooth and the phone, with split hit targets: the
    round badge toggles the radio, the rest of the row opens the page. Both get
    their own hover wash so which-does-what is visible before you commit.
  - *Sound* — master slider on home (with the output name and level under it);
    the chevron opens output/input pickers
    (`Pipewire.preferredDefaultAudioSink/Source`) and the per-app mixer.
  - *Bluetooth page* — paired devices with battery and a tap-to-reveal
    Connect/Forget row, plus a discovery toggle that lists nearby unpaired
    devices to pair with. BlueZ's `Discovering` is adapter-global, so the
    switch can flip on by itself when something else scans; the page only stops
    a scan it started — and leaving the page destroys it, so navigating back
    tears the scan down too.
  - *KDE Connect page* — one card per device with a battery bar, cell signal
    bars, and labelled Ring / Ping / Send clipboard chips (bare icon buttons
    left you guessing which was which). State comes from the daemon over DBus
    (`busctl --json=short`), *not* `kdeconnect-cli --list-devices` — that prints
    prose whose shape shifts between releases, and its "on … via …" clause
    silently broke parsing so the menu claimed "No paired devices" with the
    phone plainly connected.
  - *Keep Awake* holds a wayland idle-inhibit surface, so hypridle never sees
    the idle event and its dim/lock/suspend listeners all stay parked. The
    inhibitor lives on the **bar** window (`modules/bar/Bar.qml`), not here —
    it needs a mapped window, and this menu is destroyed on close.
  - *Media* is one snapping page per MPRIS player; flick sideways when more
    than one is playing, dots below show which. The delegate's player property
    is deliberately untyped — declaring it `MprisPlayer` makes the coercion
    from `ScriptModel`'s `modelData` fail silently to null and every binding
    throws.
  - *Keyboard backlight* is pips, not a slider: the ROG light has exactly three
    steps plus off, and tapping cycles 1 → 2 → 3 → 0. Levels come from
    `brightnessctl -m` rather than assumed, since the max differs per device
    (512 for the panel, 3 for the keyboard).
  - *Capture* — screenshot area / window / whole screen, record an area, and a
    colour picker (`hyprpicker -a`, copied). Mode is an explicit choice rather
    than one button with a hidden default, because guessing wrong costs a
    retake. While recording, the row collapses to a single Stop.
    - Every capture starts by getting the shell off the screen: popouts close,
      toasts hide, the OSD is dismissed, and the shot waits 350ms for the
      compositor to actually unmap them (the popout's close animation is 300ms).
      Not just cosmetic — a popout holding a `HyprlandFocusGrab` **swallows the
      first click meant for slurp**, which is exactly why "Rec area" appeared to
      do nothing: the selector came up behind a grab and never saw the press
      that would have started it.
    - *Window* mode is a real selector, not `activewindow` — which is whichever
      window had focus before the Control Center took it. `slurp -r` is fed the
      boxes of every mapped, non-hidden window on the visible workspaces (one
      per monitor, so it stays right with more than one screen), so hovering
      highlights a whole window and clicking takes exactly that.
    - *Whole screen* counts down 3 seconds with an OSD first, because what you
      want to photograph usually isn't reachable while a menu is open. The OSD
      is dismissed and given its 200ms fade before the shutter — it's on the
      overlay layer and would otherwise be in the picture.
    - Capture scripts run **detached**, with an `EXIT` trap that calls
      `qs ipc call capture done` to lift the hiding. They block on slurp for as
      long as the selection takes, and a tracked `Process` gets killed the
      moment the next capture starts — which does *not* kill its slurp child,
      so the orphan stays up stealing clicks from the new selector. That is how
      two slurps ended up on screen at once, one of them waiting forever.
      A trap covers every path out, including a cancelled selection; a 120s
      deadman timer covers a script that dies without running it.
    - A second capture while one is in flight is **refused**, not stacked, for
      the same reason: two layer-shell grabs, and the clicks go to whichever
      ended up on top.
    - slurp always runs *inside* the script, never as its own Quickshell
      `Process`. A bare `Process { command: ["slurp"] }` came up and drew
      nothing clickable — which is what "rec area does nothing, not even area
      selection" was. The area recording gets its geometry back through
      `qs ipc call capture region`.
  - *Theme* — latte / mocha chips, writing `Settings.theme` live.
  - The bar's own trigger takes a **scroll** for volume: the speaker module
    that used to own that gesture is a page in here now, and losing a working
    wheel-over-the-bar shortcut to a reorganisation would be a straight
    downgrade.
  - `qs ipc call popouts toggle audio|bluetooth|kdeconnect` still works and
    opens the panel straight onto that page, so keybinds from when these were
    their own dropdowns didn't have to change. A second call for the *same*
    page closes it; a different one switches pages instead of dismissing.
- **OSD** (`modules/osd/`) — volume / display brightness / keyboard backlight
  pill near the bottom of the focused screen, click-through (empty input mask),
  gone after 1.5s. Springs in on the M3 expressive-spatial curve, which
  overshoots — and the bar fill uses it too, so each step lands with a little
  rubber. Out is deliberately *not* springy: a bounce on the way out reads as a
  glitch. Every trigger also replays a scale punch, which is the only feedback
  you get when the key repeats at the end of the range (holding volume-up at
  100%, muting twice).
  - Three shapes, picked by what the value actually is. **Bar** for volume and
    display brightness. **Segments** for keyboard backlight — the ROG light has
    three steps and nothing between them, so a continuous fill would promise a
    precision the hardware doesn't have; unlit segments sit slightly small, so
    the one that just came on visibly pops. **Label** for mic mute and the CPU
    power profile, which are states rather than levels — a bar parked at some
    arbitrary fill would be actively misleading. The pill shrinks to fit in
    label mode, animated, so switching kinds mid-display morphs.
  - Volume, mic mute and the power profile need no plumbing — Pipewire and
    power-profiles-daemon signal every change, whoever made it, so media keys,
    pavucontrol, headset buttons and `powerprofilesctl` all raise it. What *is*
    filtered out: the sink coming up at startup, and the shell's own audio
    writes, so dragging the Control Center slider doesn't stack an OSD over the
    control already under your cursor. (Scrolling the bar's Control Center
    glyph, and the bar mic button, ask for one explicitly — no visible control
    there, or it's about to vanish.) Profile changes are *not* filtered: it's a
    rare deliberate act with no live readout anywhere else, and the
    confirmation is worth having even from the menu two inches away.
  - *Display* brightness has no such signal from the kernel, so those keys call
    `qs ipc call brightness up|down` and the shell raises the OSD on the press
    instead of whenever a poll next runs. Hyprland falls back to brightnessctl
    if the shell is dead, so the keys never stop working.
  - The *keyboard* backlight can't work that way and can't be intercepted at
    all: its Fn key produces **no input event on any device**. Logged every
    evdev event on all 19 devices across dozens of presses and nothing appears,
    which matches the capability bitmaps — no device declares
    `KEY_KBDILLUMUP`. asusd doesn't announce it either (its
    `xyz.ljones.Aura.Brightness` only signals for changes that went *through*
    asusd). The firmware moves the LED and the sole trace is in sysfs.
    So the shell watches `/sys/class/leds/asus::kbd_backlight/`**`brightness_hw_changed`**
    — not `brightness`. The LED core writes that attribute only for
    *hardware*-initiated changes, which makes it precisely "the user pressed
    the key" and nothing else: hypridle blanking the light on idle and the
    shell's own writes are software, never appear in it, and need no filtering
    to tell apart (verified — it held its value through both a `brightnessctl`
    and an asusd write). It's also 0.03ms to read against 1.9ms for
    `brightness`, which goes out over WMI to the EC, so it can be polled at
    120ms and catch every step of a key repeat (measured ~170ms apart) rather
    than just the last. Polled rather than `poll()`ed: the attribute does
    support `sysfs_notify`, but reaching POLLPRI from QML would mean a helper
    process babysitting a file descriptor, and at 0.03% of a core that buys
    nothing.
  - Display brightness is a **logical** 0-100 mapped onto the panel's useful
    range (`Brightness.usefulPct`). The eDP HDR backlight register spans the
    full HDR luminance, and in ordinary SDR use nothing gets brighter past the
    top fifth of it — so 100% is now the panel's real maximum instead of
    four-fifths of the way up with dead travel above. Must stay in sync with
    `MAX_PCT` in `scripts/rog-backlight-control.sh`.
- **Record overlay** (`modules/capture/`) — an area selection **arms** a
  recording rather than starting one: the first seconds were always you letting
  go of the mouse and getting out of the way. The overlay comes up with the
  region framed, everything outside it dimmed, and a pill carrying the area
  size, audio toggles, **Start** and **Cancel**. Once rolling it becomes a
  blinking dot, elapsed time and **Stop**.
  - **Nothing the overlay draws may sit inside the region** — it would all be
    in the recording, which is exactly what put a red border in the video. Qt
    strokes borders *inward*, so the frame rect is inflated by the border width
    first and the stroke lands entirely outside the captured pixels (verified
    by sampling all four edges of a finished mp4: zero border-coloured pixels).
    The pill is parked above the region, or below it when the region is hard
    against the top of the screen — never within.
  - The frame takes hyprland's own `general:col.active_border` and
    `border_size`, read live via `hyprctl` rather than hardcoded, so a recording
    looks like a focused window instead of an alarm and follows the theme in
    hypr's lua config. The colour is a gradient string ("ff64ad85 0deg"); the
    first stop is used, and hyprctl's AARRGGBB is already what Qt's `#AARRGGBB`
    literal wants.
  - Four rectangles around the region, not one with a hole: there's no
    inverse-clip primitive, and a transparent cutout stacked over a dim layer
    still darkens what's under it.
  - The window is click-through **except** for the pill — its input mask is the
    pill and nothing else, so the buttons work without blocking a recording
    you're actively driving.
  - *Audio* is two persisted toggles, desktop and mic. wf-recorder takes exactly
    one `--audio` device, so recording both needs them mixed first: a null sink
    with a loopback from each, captured through its monitor. The modules are
    unloaded in an `EXIT INT TERM` trap, so a crash or a kill can't leave a
    phantom "qshell-recording" output device in your sound settings (checked:
    zero modules left after every path).
  - Region selection runs `slurp` from a script whose geometry comes back over
    IPC, so the overlay knows where the recording is. Note slurp reports
    *global* compositor coordinates, so the overlay subtracts each screen's
    origin.
- **Notifications** — qshell owns `org.freedesktop.Notifications`. Toasts
  top-right (critical sticks + red border, actions supported), history under
  the bell. Toasts hide while a menu is open; notifications survive config
  reloads.
  - Screenshot/recording toasts carry **Open** and **Show in folder**, and
    those run *inside the shell* (`Notifs.runAction`) rather than over DBus.
    Sending the action back to the client is useless here: whatever posted the
    notification has exited, so the buttons would be dead by the time you find
    the card in the notification center. Which is exactly what was happening —
    the old `--action="scriptAction:-…"` keys are a dunst convention nothing
    here implements, and `notify-send` (the only thing listening) exits when
    the toast expires. Capture posts via `gdbus … Notify` instead of
    `notify-send`, so nothing has to sit in a glib loop waiting for a click.
  - The action identifier is a verb and nothing else; the path it acts on is
    the notification's own body, i.e. the path the card is already showing. So
    "Open" can't be talked into doing anything but what it says, even by an app
    that lies about its name. *Show in folder* goes through
    `org.freedesktop.FileManager1.ShowItems`, which highlights the file rather
    than dumping you in a folder of 400 screenshots.
  - Action buttons also silently did nothing for a second reason: the handler
    read `root.n` *after* `invoke()`, and invoke() closing the notification
    destroys the delegate mid-handler, leaving the rest of the function with no
    QML context ("ReferenceError: root is not defined"). Everything is read
    into locals first now.
- **Launcher** — bottom-center panel with the expressive spring-up, fuzzy
  search, keyboard nav.
- **Clipboard history** (Super+Shift+V) — the same panel as the launcher (same
  width, radius, item height, spring-up, gliding highlight) over the `cliphist`
  store, replacing the old `cliphist list | wofi --show dmenu` binding, so the
  existing history carries over and `wl-paste --watch cliphist store` stays the
  only writer. Enter/click copies, middle-click or Shift+Delete drops an entry.
  Image entries show a real thumbnail plus format/dimensions/size, parsed out
  of cliphist's `[[ binary data 576 KiB png 2228x609 ]]` preview. Thumbnails
  are decoded lazily (only for delegates the ListView actually builds) into
  `$XDG_RUNTIME_DIR/qshell-clipthumbs`, and that cache is wiped on shell start
  — it holds full-size decodes and the runtime dir is tmpfs, i.e. RAM.
- **Overview** (physical Alt+Tab; Super+Tab is converted to Ctrl+Tab by Toshy before Hyprland sees it) — end-4/dots-hyprland-style workspace grid
  (`overviewColumns` × however many rows the workspace count needs) with
  **live window thumbnails** (ScreencopyView via hyprland-toplevel-export) at
  their real scaled positions, app icons, and an accent ring on the focused
  workspace. Click a cell to switch, click a window to focus it, middle-click
  to close it, **drag a window onto another cell to move it there**
  (DropArea per cell, `hl.dsp.window.move({ workspace = N, follow = false,
  window = "address:…" })`). Esc / click outside dismisses.

## IPC

```sh
qs ipc -c qshell call launcher toggle       # also: open / close
qs ipc -c qshell call clipboard toggle      # clipboard history (Super+Shift+V)
qs ipc -c qshell call popouts toggle wifi   # battery / notifs
qs ipc -c qshell call popouts toggle control # control center; also: audio /
                                             # bluetooth / kdeconnect open it
                                             # straight onto that page
qs ipc -c qshell call overview toggle       # workspace overview (Alt+Tab)
qs ipc -c qshell call capture shot window   # area / window / full
qs ipc -c qshell call capture record        # select area / start armed / stop
qs ipc -c qshell call capture audio mic     # toggle mic / system audio capture
                                            # (capture done / region are called
                                            #  by the scripts, not by hand)
qs ipc -c qshell call brightness up         # down / kbdUp / kbdDown (media keys)
qs ipc -c qshell call theme set catppuccin-mocha
qs ipc -c qshell call theme list            # / get
qs ipc -c qshell call debug net             # networking introspection
qs ipc -c qshell call debug privacy         # what's using the mic / camera
```

## Settings & theming

`settings.json` (in this directory) is watched — edits apply live:

```json
{ "theme": "catppuccin-latte", "workspaces": 12, "launcherMaxShown": 8, "scale": 1.15,
  "overviewColumns": 6, "scrollFactor": 3.5 }
```

`scrollFactor` multiplies **trackpad** scrolling inside the shell's own lists
(`components/WheelScroll.qml`). Hyprland sets `input:touchpad:scroll_factor =
0.3` globally; Qt's Flickable takes that already-scaled delta at face value
while native apps layer their own acceleration on top, which is why only the
shell felt sluggish. Boosting here rather than raising the global factor keeps
every other app's scrolling untouched. Mouse wheels are deliberately left at
1× — `scroll_factor` only applies to the touchpad, so the wheel was never
slowed down.

`scale` multiplies every size token (fonts, bar height, menus, launcher) —
the whole shell grows/shrinks with one knob (`Appearance.s(px)`).

Themes live in `config/Theme.qml`, same variable contract as the old AGS
shell: transparent bar chrome with white-ish fg, surfaces (menus/launcher/
cards) carry the palette proper. Add a theme: copy a block, keep every key.

## Structure

```
shell.qml             root: Bar + Launcher + ClipboardHistory + NotificationPopups + IPC
settings.json         live-reloaded settings (theme, workspaces, scale, …)
config/               Settings (FileView+JsonAdapter), Theme, Appearance (tokens + scale)
components/           Anim/CAnim, StyledText, StateLayer (hover + ripple), StyledSwitch,
                      StyledSlider, Chip (pill button), MenuSeparator, NotificationCard,
                      WheelScroll (trackpad scroll factor), FIcon (Framework7
                      glyph), NIcon (nerd-rune glyph, for what F7 lacks), Elevation
                      (RectangularShadow drop shadow — must sit BEHIND the surface as a
                      sibling; as a child it paints over the parent's fill)
services/             Audio (Pipewire sink), Net (wifi/ethernet — named Net because
                      Quickshell.Networking exports a `Network` type that would shadow it),
                      Apps (fuzzy search), Notifs (notification daemon state), Vpn (nmcli),
                      Tailscale (CLI + pkexec escalation), KdeConnect (daemon over DBus),
                      Clipboard (cliphist history), Brightness (display + kbd via
                      brightnessctl), Idle (keep-awake flag; inhibitor is on the bar),
                      Camera (is anything using a webcam — uvcvideo refcount),
                      Asus (fan profile / charge limit / GPU mode), Power (CPU profile
                      + its one set of names and glyphs), Capture (grim,
                      slurp, wf-recorder + the live region geometry), Osd (what the
                      on-screen display is showing and for how much longer)
modules/bar/          Bar, Workspaces + WorkspaceSlot, Clock, Tray + TrayItem, NotifsStatus,
                      WifiStatus, BatteryStatus, ControlStatus, PrivacyStatus
modules/bar/popouts/  Popouts (dropdown host) + WifiMenu, BatteryMenu, NotifsMenu, TrayMenu
modules/control/      ControlCenter (push navigation host) + Home, AudioPage,
                      BluetoothPage, KdeConnectPage, and the shared Card / Badge /
                      PageHeader the pages are built from
modules/launcher/     Launcher, AppItem
modules/clipboard/    ClipboardHistory, ClipItem (cliphist-backed, launcher styling,
                      lazy image thumbnails)
modules/capture/      RecordOverlay (dims around a live area recording)
modules/notifications/NotificationPopups (toast stack)
modules/osd/          OsdPanel (volume / brightness / keyboard-backlight pill)
modules/overview/     Overview (grid, drag/drop plumbing), OverviewWindow (live thumbnail)
```

## Toolchain notes

- Plain QML — no build step, nothing to install.
- Needs: `quickshell-git` (0.3+ — `Networking`, `Bluetooth`, `Notifications`,
  `UPower`/PowerProfiles, `Pipewire` modules), power-profiles-daemon,
  OperatorMono Nerd Font, `rose-pine-dawn-icons` (pinned via pragma in
  `shell.qml`).
- Pipewire gotcha: node properties (`media.class`) only populate for nodes
  held by a `PwObjectTracker` — the Sound page tracks all nodes while open.
- Animation token values are from caelestia-dots/shell
  (`plugin/src/Caelestia/Config/tokens.hpp`) — Material 3 expressive motion
  tokens; the QML here is original.
- **Icons are Framework7 Icons** (MIT), an SF-Symbols-alike set, used straight
  from the upstream `Framework7Icons-Regular.ttf` — no patched copy, no
  codepoint map. The font is *ligature*-driven, so `components/FIcon.qml` just
  sets the text to the icon's name and `liga` substitutes the glyph, longest
  match first (`wifi_slash` beats `wifi`). A name the font doesn't know renders
  as literal letters, which is a louder failure than tofu.
  Framework7 ships **no bluetooth glyph** (nor mouse/watch), so those stay nerd
  runes drawn with `components/NIcon.qml`, sized against the F7 icons beside
  them. Super+N toggles the notification center;
  touchpad edge-swipe gestures aren't possible (libinput treats 2-finger
  contact as scroll, and hl.gesture has no exec action).
