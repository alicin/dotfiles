# qshell

Desktop shell for Hyprland on h4l9000, built with [Quickshell](https://quickshell.org/)
(QML). Successor to the AGS prototype in the j4rv15 repo (`shell/`).

Transparent top bar drawn over the wallpaper — workspaces left, clock center,
tray / notifications / bluetooth / wifi / audio / battery right — plus a
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
- **Tray** — collapsed behind an ellipsis, items slide out on hover. Leftward,
  because the status Row is right-anchored: growing left leaves the ellipsis
  and every icon after it in place instead of shoving the trigger out from
  under the cursor. Stays open while one of its own menus is.
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
  - *Bluetooth* — adapter toggle, paired devices with battery and a
    tap-to-reveal Connect/Forget row, plus a discovery toggle that lists
    nearby unpaired devices to pair with. BlueZ's `Discovering` is
    adapter-global, so the switch can flip on by itself when something else
    scans; the menu only stops a scan it started.
  - *Audio* — master + per-app stream sliders, output/input device pickers
    (`Pipewire.preferredDefaultAudioSink/Source`).
  - *Battery* — Power Saver / Balanced / Performance via power-profiles-daemon,
    charge estimate. Bar shows a drawn horizontal battery. Below that, the ROG
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
- **KDE Connect** — device list with battery, charging and cell network, plus
  ring / ping / push-clipboard actions and an app launcher (kdeconnectd is
  autostarted from hyprland's startup.lua). State comes from the daemon over
  DBus (`busctl --json=short`), *not* `kdeconnect-cli --list-devices` — that
  prints prose whose shape shifts between releases, and its "on … via …"
  clause silently broke parsing so the menu claimed "No paired devices" with
  the phone plainly connected.
- **Control Center** (the sliders glyph, next to the bell) — deliberately only
  what has no bar module of its own: Do Not Disturb and Keep Awake tiles, a
  media card, display brightness, keyboard backlight, and a session row
  (shutdown / restart / sleep / log out). Wi-Fi, Bluetooth, volume and power
  profile were removed — they each own a status icon already, and duplicating
  them meant two places to keep in sync.
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
  - *Theme* — latte / mocha chips, writing `Settings.theme` live.
- **Record overlay** (`modules/capture/`) — while an *area* recording is live,
  everything outside the region is dimmed, with a red frame and a blinking
  size pill. Four rectangles around the region, not one with a hole: there's no
  inverse-clip primitive, and a transparent cutout stacked over a dim layer
  still darkens what's under it. The window has an empty input mask so it's
  entirely click-through — it's annotation, and blocking input on a recording
  you're actively driving would be worse than useless.
  Region selection runs `slurp` from QML rather than inside a shell pipeline,
  so the geometry comes back and the overlay knows where the recording is.
  Note slurp reports *global* compositor coordinates, so the overlay subtracts
  each screen's origin.
- **Notifications** — qshell owns `org.freedesktop.Notifications`. Toasts
  top-right (critical sticks + red border, actions supported), history under
  the bell. Toasts hide while a menu is open; notifications survive config
  reloads.
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
qs ipc -c qshell call popouts toggle wifi   # bluetooth / audio / battery / notifs
qs ipc -c qshell call overview toggle       # workspace overview (Alt+Tab)
qs ipc -c qshell call theme set catppuccin-mocha
qs ipc -c qshell call theme list            # / get
qs ipc -c qshell call debug net             # networking introspection
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
                      StyledSlider, MenuSeparator, NotificationCard, FIcon (Framework7
                      glyph), NIcon (nerd-rune glyph, for what F7 lacks), Elevation
                      (RectangularShadow drop shadow — must sit BEHIND the surface as a
                      sibling; as a child it paints over the parent's fill)
services/             Audio (Pipewire sink), Net (wifi/ethernet — named Net because
                      Quickshell.Networking exports a `Network` type that would shadow it),
                      Apps (fuzzy search), Notifs (notification daemon state), Vpn (nmcli),
                      Tailscale (CLI + pkexec escalation), KdeConnect (daemon over DBus),
                      Clipboard (cliphist history), Brightness (display + kbd via
                      brightnessctl), Idle (keep-awake flag; inhibitor is on the bar),
                      Asus (fan profile / charge limit / GPU mode), Capture (grim,
                      slurp, wf-recorder + the live region geometry)
modules/bar/          Bar, Workspaces + WorkspaceSlot, Clock, Tray + TrayItem, NotifsStatus,
                      WifiStatus, BtStatus, VolumeStatus, BatteryStatus
modules/bar/popouts/  Popouts (dropdown host) + WifiMenu, BluetoothMenu, AudioMenu,
                      BatteryMenu, NotifsMenu, TrayMenu
modules/launcher/     Launcher, AppItem
modules/clipboard/    ClipboardHistory, ClipItem (cliphist-backed, launcher styling,
                      lazy image thumbnails)
modules/capture/      RecordOverlay (dims around a live area recording)
modules/notifications/NotificationPopups (toast stack)
modules/overview/     Overview (grid, drag/drop plumbing), OverviewWindow (live thumbnail)
```

## Toolchain notes

- Plain QML — no build step, nothing to install.
- Needs: `quickshell-git` (0.3+ — `Networking`, `Bluetooth`, `Notifications`,
  `UPower`/PowerProfiles, `Pipewire` modules), power-profiles-daemon,
  OperatorMono Nerd Font, `rose-pine-dawn-icons` (pinned via pragma in
  `shell.qml`).
- Pipewire gotcha: node properties (`media.class`) only populate for nodes
  held by a `PwObjectTracker` — the audio menu tracks all nodes while open.
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
