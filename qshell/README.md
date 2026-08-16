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
- `apps.lua` `M.control*` — Super+comma opens the Control Center; Super+Shift+
  comma enters the `control` **submap** for its pages ((s)ound, (b)luetooth,
  (k)de connect, (d)isplays, (c)ontrol). A submap rather than four more
  modifier combos: the pages are siblings of one thing and aren't hot keys, and
  Super+Shift had none of the obvious mnemonics left. Entering raises the OSD
  key legend (`services/Osd.qml` `submapHints`) — keep that in sync with
  `config/hypr/lua/submaps/control.lua`, since Hyprland's `submap` event
  carries only the name, never the description.
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
  container is. Presence is the signal, so none of them has an idle state: a
  **green camera** while a webcam is open, an **amber mic** while the mic is
  live (not muted), a **blue screen** while a portal screencast is running.
  Clicking the mic mutes it, which also makes it disappear — the light is both
  the warning and the switch that clears it. All three fade and scale in,
  because appearing out of nowhere in the corner of a bar is easy to miss and a
  moving thing isn't.
  - The cast light is **not** clickable, unlike the mic: there is no honest way
    to stop a share from the bar. The portal owns the session, and killing the
    node out from under it hangs the consumer rather than ending the share.
  - Telling a cast from a camera is not the media class, which was the
    assumption going in and is wrong: both portal backends installed here
    publish the cast as `Video/Source` — the *same* class the v4l2 webcams
    carry. What separates them is the v4l2 tail the cameras drag behind them
    (`device.api`, `media.role=Camera`, `api.v4l2.path`, a `v4l2_` node name),
    any one of which hands the node to `Camera.qml` instead. The portal's own
    giveaway (`xdph-streaming-` / `xdpw-stream-`) lands in `media.name`, not
    `node.name`. See `services/Screencast.qml`, which is candid about having
    been verified against a synthetic PipeWire stream rather than a real cast —
    `qs ipc call debug screencast` is how you check it against one.
  - Badges rather than bare glyphs because a coloured icon on transparent bar
    chrome is at the mercy of the wallpaper behind it, while a solid fill
    carries its own contrast and reads as a status light instead of one more
    clickable icon. Their fills (`Theme.privacyCam` / `privacyMic` /
    `privacyCast`) are
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
  - *Microphone* is the kill switch, and it lives beside the output level
    rather than in a tile of its own — a kill switch belongs next to the thing
    it cuts. Its glyph goes amber while something is actually capturing, the
    same colour as the bar's privacy light, so the two read as one fact rather
    than two coincidences; the caption names who is listening. The bar light is
    still only the warning half: it exists solely while audio is flowing, so
    once you cut the mic it has nothing left to say and no way to hand it back.
  - Tailscale is deliberately **not** here. It was a tile briefly and did not
    earn a permanent third of a row for something toggled about once a week,
    when the Wi-Fi menu already carries it with the exit node and the tailnet
    device list beside it. NetworkManager VPNs stay there too: they are a list
    (this host has two WireGuard profiles), and a tile has one tap and two
    lines — it could name which one is up but not let you choose.
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
  gone after 1.5s. Scales and fades in, decelerating, and never overshoots —
  the M3 `*Spatial` curves all rise past 1 before settling, so none of them are
  used here; `emphasizedDecel` throughout, and a plain accelerate on the way
  out. There is deliberately no pulse on re-trigger either, so holding
  volume-up at 100% shows a steady pill rather than a repeating twitch.
  - Three shapes, picked by what the value actually is. **Bar** for volume and
    display brightness. **Segments** for keyboard backlight — the ROG light has
    three steps and nothing between them, so a continuous fill would promise a
    precision the hardware doesn't have; unlit segments sit slightly small, so
    the one that just came on grows to full size. **Label** for mic mute and the CPU
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
  search, keyboard nav. Apps are only the default source: a **prefix character
  at the front of the query swaps the source**, and the `?` button in the
  search field lists every one of them (each row walks you into that mode).
  - `>` **commands** — capture, notifications, Keep Awake, night light, Wi-Fi,
    power profiles, themes, lock/suspend/reboot/power off/log out/reload. Every
    one of these already had a service behind it and no keyboard route to it.
    The destructive three want a second Enter, which the row says out loud.
  - `/` **windows** — Super+Shift+W, replacing the `hyprctl clients | jq |
    wofi` pipeline. Ordered most-recently-focused (`services/Windows.qml`
    keeps that stack off `activewindowv2`); focusing a window parked on a
    special workspace pulls the workspace up with it.
  - `:` **emoji** — Super+period, over `data/emoji.json` (the installed emoji
    font's cmap ∩ the Unicode character database, so every entry both has a
    name to search and a glyph that renders). Enter copies. The table loads
    lazily and recently-picked ones sort first.
  - `!` **run** — a command line; Shift+Enter runs it in a terminal that stays
    open on the output. A Run row also appears as the *last resort* when a
    plain query matches no app, in place of "No matches".
  - Anything that parses as arithmetic answers itself in a row above the
    results (`services/Search.qml` has a small recursive-descent parser —
    `eval()` on arbitrary typed text is not a thing this shell does), and
    Enter copies the answer.
  - **Units, currency and conversions go to `qalc`** (libqalculate): `180 GB to
    MB`, `40 USD in CAD` (live ECB rates), `5 km + 3 mi`, `2^10`. The local
    parser stays the fast path — it answers in the same frame, so ordinary
    arithmetic never flickers through a placeholder and never spawns a process;
    qalc is only asked what the parser cannot do, and its answer replaces a `…`
    when it lands (debounced 150ms, one process at a time).
    - **qalc cannot be the gate** for "is this a calculation". Verified:
      `qalc -t "not an expression at all"` prints `n = 0` and exits 0 — it reads
      anything as an assignment and answers happily. So two deliberately narrow
      patterns decide instead, both requiring a leading number, which is what
      keeps `firefox`, `settings` and `1password` out; the conversion pattern
      also requires letters after `to`/`in`/`as`, which is what keeps `2 in 1`
      out.
    - qalc answers with a **Unicode minus** (U+2212), which looks right and
      pastes wrong — it is not a hyphen and anything reading the copied value
      back as a number chokes. Normalised on the way in.
    - Note `100 F to C` is farads to coulombs, not Fahrenheit — that is qalc's
      unit table, not a bug here. `degF to degC` is the spelling it wants.
  - Desktop-entry **actions** ("New Private Window") ride along under their
    app, findable by the app's name or by the action's own words.
- **Clipboard history** (Super+Shift+V) — a wide strip across the bottom of
  the screen holding one **card per entry**, in the shape macOS
  [Paste](https://pasteapp.io/) uses: who copied it across the top, the
  content itself filling the middle at a size worth reading, what/when along
  the bottom. The 56px rows it replaces could show the first line of anything,
  which is the wrong line as soon as you are after the *second* URL you copied
  off a page, or the right one of four screenshots. Still the same `cliphist`
  store as the old `cliphist list | wofi --show dmenu` binding, so history
  carries over.
  - **Kind chips** (All / Pinned / Text / Links / Images / Files / Colors)
    filter the strip; Tab walks them. A colour-valued entry draws itself as
    the colour, which is the one payload whose value *is* what it looks like.
  - **Ctrl+Q shows the entry as a QR code**, for picking a link up on a phone —
    the other half of `capture qr`, which reads one off the screen. Offered for
    text, links and colours only: an image entry has no text to encode and a
    file entry's payload is a path that means nothing on the other device.
    - It encodes the **full entry**, never the card's preview — cliphist's
      listing is truncated, and a QR built from that is a perfectly valid code
      for the wrong string.
    - The payload never crosses into QML: the pipeline ends in `base64` and the
      result goes straight into an `Image` as a `data:` URI, so no clipboard
      entry is ever written to disk. `-s 1` makes the PNG one pixel per module
      so the view scales it by an integer with `smooth: false` — a filtered QR
      is a blurred QR, and blurred is unscannable.
    - The plate is **the one surface in the shell that ignores the palette**:
      a QR is read by a camera and the spec assumes dark modules on a light
      ground, so it stays black-on-white in all 16 themes. The chrome around it
      is themed; the code and its quiet zone are not.
    - Past qrencode's ~2953-byte ceiling it says "too long to encode" rather
      than showing a truncated code that scans to the wrong thing. `pipefail`
      is load-bearing there: `base64` of empty input exits 0.
  - **Opening the picker always lands on the first card**, with no slide. Two
    things had to be true for that: the reset lives on the *model*, keyed on the
    query and filter actually rendered (the launcher's list carries the same fix
    and documents why — two handlers firing off one notification in an order QML
    does not promise), and it re-asserts on every rebuild until the selection
    genuinely moves, because `Clipboard.refresh()` is a subprocess whose result
    lands long after `onOpenChanged`. Before that, `highlightRangeMode:
    ApplyRange` re-derived `currentIndex` from wherever `contentX` sat during
    the open relayout, which landed on card 749 of 750 — and Right then wrapped
    modulo count straight back to the first.
  - **Source attribution**: cliphist stores content and nothing else — no app,
    no timestamp — and both are knowable only at the instant of the copy. The
    `wl-paste --watch` lines therefore run `scripts/clip-store.sh`, which *is*
    `cliphist store` plus a TSV of `id, seconds, window class, title`. The
    picker degrades to naming the kind ("Text", "Image") and showing no time
    if that file is missing; it decorates cards, it does not drive them.
  - **Pins** survive both a screenshot session pushing entries off the end of
    the store and `cliphist wipe`, because everything cliphist can name an
    entry by dies with the entry: a pin keeps its own copy of the bytes under
    `statePath("clipboard-pins")` and never asks cliphist for anything again.
    Bytes go back out under the mime type they came in as, or the target sees
    nothing it can take.
  - **Paste-on-select** (`clipboardPaste`, off by default) sends the paste
    into the window the picker was opened over, addressed by window rather
    than aimed at whatever has focus — the focus grab is still coming down as
    it goes out. Terminals get Ctrl+Shift+V, matched by class against
    `clipboardPasteTerminals`. The copy is a tracked Process, not
    `execDetached`, so the paste can wait for wl-copy to own the selection
    rather than for a guessed delay.
  - Enter copies (or pastes), ←/→ select, Ctrl+P pins, Ctrl+D or middle-click
    drops one, and **Clear** wipes the history behind a second press — pins
    are not history and do not go with it. The key legend along the bottom is
    Paste's, and is there for the same reason the launcher grew a ? button.
  - Thumbnails are decoded lazily (only for delegates the ListView actually
    builds) into `$XDG_RUNTIME_DIR/qshell-clipthumbs`, and that cache is wiped
    on shell start — it holds full-size decodes and the runtime dir is tmpfs,
    i.e. RAM.
- **Overview** (physical Alt+Tab; Super+Tab is converted to Ctrl+Tab by Toshy before Hyprland sees it) — end-4/dots-hyprland-style workspace grid
  (`overviewColumns` × however many rows the workspace count needs) with
  **live window thumbnails** (ScreencopyView via hyprland-toplevel-export) at
  their real scaled positions, app icons, and an accent ring on the focused
  workspace. Click a cell to switch, click a window to focus it, middle-click
  to close it, **drag a window onto another cell to move it there**
  (DropArea per cell, `hl.dsp.window.move({ workspace = N, follow = false,
  window = "address:…" })`). Esc / click outside dismisses.

- **Read the screen** (`scripts/ocr.sh`, Ctrl+Shift+8 / Ctrl+Shift+9) — drag a
  region and get its **text** on the clipboard (PowerToys' Text Extractor), or
  decode a **QR/barcode** in it. Both go through `Capture.withUiHidden()` first:
  the bar and any live toast are on the screen being read, and not hiding them
  OCRs the shell's own UI into your clipboard.
  - **Supersampling is the feature**, not a nicety. Measured on this display: at
    native scale tesseract turns a line of 12pt terminal text into
    `faiiged Wds Ld4L4lo Lk juusl vianuing`; at 2x native the same line comes
    back verbatim. But grim's `-s` is an **absolute** output scale, not a
    multiplier — its default is already the greatest scale of the outputs being
    captured (1733x400 for a 1300x300 logical region on a scale-1.33 monitor),
    so a hardcoded `-s 2` is only 1.5x here and would be a *downscale* on a 2x
    display. The factor is computed against the monitor's scale.
  - Capped at ~8MP: tesseract is roughly linear in pixel count and holds the
    page in memory, so an unbounded upscale of a full-screen selection is a
    multi-second stall with the shell's UI hidden, for no extra accuracy.
  - **No temp file anywhere** — grim writes PNG to stdout and tesseract reads
    `-` from stdin, so a cancelled or crashed run leaves nothing behind. A
    screen region is exactly the class of thing (a password field, a DM) that
    should not outlive the copy.
  - A failed read **does not touch the clipboard**: losing what you had copied
    because the OCR found nothing is worse than the failure itself.
  - The toast preview is truncated by *characters*, not bytes — splitting a
    multi-byte character makes gdbus reject the whole `Notify` call, which does
    not mangle the notification, it means no notification appears at all.
- **Picture-in-Picture** (Super+Shift+I — `services/Pip.qml`, `modules/pip/`) —
  a live, always-on-top, scaled-down view of one window, so a build or a log
  stays watchable from inside something else. Same mechanism as the overview's
  thumbnails (hyprland-toplevel-export through `ScreencopyView`) pointed at one
  window instead of all of them. Drag it anywhere, click it to jump to the
  source, Super+Ctrl+Shift+I cycles the corners.
  - Holds the window's **address, never the toplevel object**: Quickshell
    destroys a `HyprlandToplevel` outright on `closewindow` and every held
    reference silently becomes null, which would leave a frozen picture of a
    window that no longer exists. The source going away unpins instead.
  - The surface is **screen-sized and therefore constant**, with `mask: Region`
    around just the card — so the card can be dragged and resized without any
    animated child ever reaching the Wayland surface. That is the trap the OSD
    fell into, where deriving `implicitWidth` from an animating pill resized the
    layer surface every frame and made `rules.lua` fade `qshell:.*` underneath
    the real animation.
  - Nothing is mapped until something is pinned (a `LazyLoader`), and the card
    hides itself outright while a capture is in flight — it is on the Overlay
    layer, so it *is* in the screenshot otherwise.
- **Shortcuts cheat sheet** (Super+/ — `modules/keycheat/`) — the whole keymap
  as a grid of grouped cards, **generated from `~/.config/hypr/lua/binds.lua`**
  (the file Hyprland actually loaded, not the repo copy) by reading its
  `-- ▸ Group` headers and trailing `-- label` comments. `watchChanges` is on,
  so editing a bind updates the sheet with no reload.
  - Was `bin/keycheat-overlay.py`, a standalone GTK4 + gtk4-layer-shell app
    with a **hardcoded Catppuccin-Mocha palette** — fine while the shell was
    always dark, and a slab of `#1b1c2b` over a light desktop the moment it
    wasn't. As a shell surface it draws from Theme/Appearance and retextures
    with every other panel. It also inherits the standard dismissal set: the
    GTK version took keyboard focus `NONE` and could only be closed by clicking
    or re-firing the bind, this one takes `OnDemand` and answers Esc.
  - Three parsing cases the source needs help with: the workspace binds are
    generated in a Lua `for` loop with no per-key label (summarised as
    `Super + 1…9`), gestures are `hl.gesture` rather than `hl.bind` and carry
    no label (synthesised from `fingers`/`direction`/`action` — the Python
    version parsed only `hl.bind`, so the Gestures group came out empty and was
    dropped), and **text editing lives in Toshy, not in binds.lua**, so that
    group is hand-written in the module and listed in *physical* keys.
  - Cards are packed into balanced masonry columns rather than a row-major
    flow: one tall group otherwise forces a tall row and every short card
    beside it leaves a hole.

## IPC

```sh
qs ipc -c qshell call launcher toggle       # also: open / close
qs ipc -c qshell call launcher mode /       # open straight into a prefix mode
                                            # (> commands, / windows, : emoji,
                                            #  ! run, ? help); same key closes
qs ipc -c qshell call clipboard toggle      # clipboard history (Super+Shift+V)
qs ipc -c qshell call popouts toggle wifi   # battery / notifs
qs ipc -c qshell call popouts toggle control # control center; also: audio /
                                             # bluetooth / kdeconnect / display
                                             # / settings open it straight onto
                                             # that page
qs ipc -c qshell call launcher mode '#'      # theme picker (swatches)
qs ipc -c qshell call overview toggle       # workspace overview (Alt+Tab)
qs ipc -c qshell call keycheat toggle       # shortcuts cheat sheet (Super+/)
qs ipc -c qshell call capture ocr           # drag a region -> its text on the
                                            # clipboard (Ctrl+Shift+8)
qs ipc -c qshell call capture qr            # drag a region -> decode a QR code
                                            # in it (Ctrl+Shift+9)
qs ipc -c qshell call pip toggle            # picture-in-picture the focused
                                            # window; also pin <addr> / unpin
qs ipc -c qshell call pip corner            # no argument cycles the corners
qs ipc -c qshell call pip size large        # small / medium / large, or a
                                            # fraction of the screen width
qs ipc -c qshell call pip status            # what is pinned, and is it alive
qs ipc -c qshell call capture shot window   # area / window / full
qs ipc -c qshell call capture record        # select area / start armed / stop
qs ipc -c qshell call capture audio mic     # toggle mic / system audio capture
                                            # (capture done / region are called
                                            #  by the scripts, not by hand)
qs ipc -c qshell call brightness up         # down / kbdUp / kbdDown (media keys)
qs ipc -c qshell call theme set catppuccin-mocha
qs ipc -c qshell call theme list            # / get
qs ipc -c qshell call debug net             # networking introspection
qs ipc -c qshell call debug privacy         # what's using the mic / camera / screen
qs ipc -c qshell call debug screencast      # every video node + why it did or
                                            # didn't count as a cast
qs ipc -c qshell call debug ddc             # DDC displays found, if any
qs ipc -c qshell call debug search '>power' # what the launcher would list
qs ipc -c qshell call debug notif           # every notification's raw hints —
                                            # image://qsimage/… means raw
                                            # image-data, i.e. no path to judge
qs ipc -c qshell call debug clip            # clipboard strip: selected index,
                                            # count, filter, query, contentX
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

`notifIconOnlyApps` is an anchored, case-insensitive regex over a notification's
app name *and* its desktop entry, naming senders whose "image" is never a
picture — only their own launcher icon. Electron is the reason it exists: the
only way it attaches an icon is `notify_notification_set_image_from_pixbuf()`,
which sets the **`image-data`** hint, and the spec calls that hint *content*, so
every Claude notification grew a 150px logo under it. `NotificationCard.qml`
rejects the shape of that mistake generically (a square blob is an icon), and
this is the manual override for whatever gets through — a sender whose logo
isn't square, say. Confirm what an app actually sends with
`qs ipc -c qshell call debug notif`.

Every key except `clipboardPasteTerminals` and `notifIconOnlyApps` also has a
control on the **Settings page** (Control Center → Settings, or `qs ipc call popouts toggle settings`).
Numeric setters stage the value in memory and debounce the file write by 220ms:
a slider under a finger emits every frame, and rewriting — and re-watching, and
re-reparsing — settings.json sixty times a second is both wasteful and the
classic way to read back a half-written file. The panel widens from 340 to 470
for this page alone, because it is rows of "label ………… value" with free-text
fields in them rather than the one-tap toggles home is sized for.

### Themes

Sixteen of them in `config/Theme.qml`, a plain data map: Catppuccin ×4, Rosé
Pine ×3, Tokyo Night ×2, Gruvbox ×2, Everforest ×2, Nord, Dracula, Kanagawa.
Same variable contract as the old AGS shell — transparent bar chrome with
white-ish fg, surfaces (menus/launcher/cards) carrying the palette proper. Add
one by copying a block and keeping every key.

Pick them in the **launcher's `#` mode**, which paints each row in that theme's
own surface and accent and stays open across picks so you can compare — the
panel restyles itself into its own preview. The Control Center and the Settings
page both just name the current theme and hand off to it; a chip per theme
sharing a 340px panel is 18px each.

Two rules an upstream palette will not give you, both enforced by hand because
they only exist because of how this shell draws:

- **Bar chrome needs luminance, not fidelity.** `barFg` and the four state
  tints are drawn over an arbitrary wallpaper under a 75%-black drop shadow
  that exists to make light glyphs pop — so it buries dark ones. A *light*
  theme's palette red is a dark red, and latte's critical-battery glyph
  measured 0.14 relative luminance against its own 1.00 barFg. Light themes
  therefore take `barOk`/`barWarn`/`barUrgent`/`barAwake` from their family's
  **dark** variant. Their `ok`/`warn`/`urgent` siblings, drawn on panels, keep
  the light values.
- **Foregrounds belong to their own fill.** `accentFg`, `wsActiveFg` and
  `wsUrgentFg` each contrast with one specific colour, and borrowing one for a
  different fill borrows a guarantee that was never made — the charging bolt
  was `accentFg` on `barOk`, which is white-on-pale-green at 1.49:1 in latte.
  Use `Theme.contrastFg(fill)` when the fill is a theme colour rather than a
  known one.

### GTK apps get the palette too

`scripts/theme-sync.sh` used to give GTK only light/dark — `adw-gtk3` or
`adw-gtk3-dark` plus the portal preference — so all sixteen themes collapsed
into two looks and Nautilus was identical under Gruvbox and under Nord.
`scripts/gtk-theme-css.py` now writes the real palette into
`config/gtk-{3,4}.0/gtk.css` as libadwaita `@define-color` overrides (those
directories *are* `~/.config/gtk-{3,4}.0`, by symlink).

- **Derived from `Theme.qml`, not typed out again.** A second hand-maintained
  copy of sixteen palettes is a second thing to get wrong, and the two would
  disagree the first time a colour was tuned in one of them. `surfaceBg` is
  stored `#AARRGGBB`, so dropping the alpha digits is exactly the upstream base
  colour (`#f7eff1f5` → `#eff1f5`, Latte's `base`).
- **CSS rather than a theme name, because of libadwaita**: GTK4 apps ignore
  `gtk-theme-name` entirely and read these named colours, which is precisely
  why they only ever followed light/dark. GTK3 reaches the same names through
  adw-gtk3, so one palette drives both.
- Derived shades follow libadwaita's own convention — views sit *above* the
  window on light themes (whiter) and *below* on dark ones — so depth cues do
  not invert. Borders are a tint of the foreground, never a neutral grey, which
  reads as dirt on a tinted ground like Everforest or Rosé Pine.
- `accent_color` (text) is contrast-corrected against the window background,
  separately from `accent_bg_color` (fills): Latte's mauve is 3.1:1 as link
  text on its own base, which is a pastel that looks right as a button and is
  unreadable as a word.
- **Measured limitation: the palette applies at app startup.** Light/dark
  follows the portal live, but a running app does not re-read `gtk.css` and
  poking gsettings does not make it — so a theme change recolours GTK apps on
  their *next* launch. Nautilus is single-instance, so `nautilus --new-window`
  reuses the old daemon and its old colours; it needs a real kill to re-read.

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
modules/launcher/     Launcher, ResultItem (apps / commands / windows / emoji /
                      run / calculator — see services/Search.qml)
modules/clipboard/    ClipboardHistory (Paste-style card strip), ClipCard
                      (cliphist-backed, lazy thumbnails, source attribution)
modules/capture/      RecordOverlay (dims around a live area recording)
modules/notifications/NotificationPopups (toast stack)
modules/osd/          OsdPanel (volume / brightness / keyboard-backlight pill)
modules/overview/     Overview (grid, drag/drop plumbing), OverviewWindow (live thumbnail)
modules/pip/          PipView (screen-sized host surface + IPC), PipCard (the floating
                      live thumbnail — capture, chrome, drag)
modules/keycheat/     KeyCheat (shortcut sheet, parsed from ~/.config/hypr/lua/binds.lua)
```

Two services carry state their module cannot own alone:

```
services/Pip.qml      the pinned window's ADDRESS (never the toplevel — Quickshell
                      destroys those on closewindow), corner, size. A singleton
                      because services/Search.qml offers the row and cannot import
                      qs.modules.
services/Search.qml   the six launcher modes, the arithmetic parser, and the qalc
                      bridge (gate + debounce + Unicode-minus normalisation)
```

Outside the shell:

```
scripts/ocr.sh        read a region: [text|qr]. Takes an optional geometry argument
                      so it can be tested without a human dragging a rectangle.
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
