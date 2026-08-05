# qshell — review backlog

From a full-shell UI/UX review (2026-08-03): every item below was verified against
the actual code, with file:line refs where it helps. ★ = highest daily-use payoff.

## Bug — fix regardless

- [x] `services/Capture.qml:342` calls `notifySnippet()`, deleted in the capture
      refactor — throws a TypeError every time the pgrep poll sees a recording end,
      so the externally-killed-recording path (wl-copy + toast) is dead. Script-driven
      stops still notify, which is why testing didn't catch it. Either delete the
      now-redundant block or use the gdbus form from `scripts/lib/capture.sh`.

## UI/UX improvements

### Bar

- [x] ★ Mic privacy light keys off _unmuted_ (lit all day) instead of actual
      capture — bind to `Audio.micInUse`; `micUsers` names the listening apps and is
      unused (`PrivacyStatus.qml:102`, `services/Audio.qml:19-54`)
- [x] ★ Notification badge counts all retained notifications (cap 80), never
      resets on viewing — track `lastSeen` on menu-open, badge only newer
      (`NotifsStatus.qml:33`, `services/Notifs.qml:28`)
- [x] ★ Touchpad scroll overshoots: workspace/volume wheel act once per event,
      no detent accumulation — accumulate ±120 angleDelta
      (`Workspaces.qml:52`, `ControlStatus.qml:25`)
- [x] Top-edge dead zone: modules are 26px centered in the 34px bar, so
      edge-slam clicks miss — extend hit areas to full bar height
- [x] Hover-slide between popouts while one is open (macOS menubar behavior);
      the panel-morph animation exists, only the hover trigger is missing
- [x] Special workspaces (scratchpad/void) invisible: focusing one blanks the
      active pill, parked windows appear nowhere — add a chip at the row's end
      (`Workspaces.qml:20,113`)
- [x] Per-monitor workspace focus: both bars highlight the global
      `Hyprland.focusedWorkspace` — use each monitor's own activeWorkspace
- [x] Route keybind/IPC popouts to the focused monitor — currently
      last-registered bar wins, per the code's own comment (`Bar.qml:120-154`)
- [x] Wifi glyph: one binary >25% threshold, no connecting state on the bar —
      `Net.strength` is already 0-100
- [x] Tray: forward wheel events to applets; surface `NeedsAttention` (dot on
      the ellipsis / auto-expand); nothing identifies a monochrome icon
- [x] Workspace slots cap at 3 icons with no "+n" (`WorkspaceSlot.qml:93`)
- [x] Camera privacy light: pointer cursor + ripple but no handler — dead
      affordance (`PrivacyStatus.qml:93-97`)

### Popout menus

- [x] ★ Body-click on a notification card dismisses it — should invoke the
      app's `"default"` action (currently rendered as a pill literally labeled
      "default") or expand; keep dismissal on the ×
      (`components/NotificationCard.qml:62-65`)
- [x] ★ Ethernet row: full click affordance whose only action is disconnect;
      can't reconnect once down — use the switch pattern the VPN rows already have
      (`WifiMenu.qml:392-399`)
- [x] Panel claims to morph between menus but x/width/height snap — add
      Behaviors while already open (`Popouts.qml:108-155`); also split the close
      anim (300ms _entrance_ curve both ways reads sluggish on dismiss)
- [x] Stale Wi-Fi password unrecoverable: known networks always reuse the
      stored PSK, the password row never reopens on failure
      (`WifiMenu.qml:219-227,330-345`)
- [x] "Scanning…" filler is hardcoded whenever <3 networks listed, even when
      `Net.scanning` is false or the adapter is absent (`WifiMenu.qml:361-373`)
- [x] PSK entry: no reveal toggle, no connect button, "…" is the whole
      progress story, Esc while typing closes the entire popout instead of the row
- [x] No keyboard navigation in any menu — Escape is the only key handled;
      arrows/Enter over rows with a visible focus state
- [x] Notifs list: no removal animations (clear-all snaps the panel height in
      one frame), no scrollbar, unclamped drag — port WifiMenu's
      scrollbar/interactive/bounds pattern (`NotifsMenu.qml:94-118`)
- [x] Bodies truncate at 3 lines everywhere with no expand — long messages are
      unreadable in the whole shell (`NotificationCard.qml:146-157`)
- [x] Tailscale switch fails silently (NeedsLogin/stopped/no-CLI/dismissed
      pkexec all look identical); VPN toggles sit dead 1.5s even on success —
      busy + failure states (`Tailscale.qml:59-72`, `Vpn.qml:20-30`)
- [x] Battery menu header can render blank (no ETA yet after unplug) and never
      shows the percentage (`BatteryMenu.qml:124-135`)
- [x] Tray menus: no app-identity header; nested submenu entries silently
      fire-and-close (`TrayMenu.qml:144-153`)

### Control Center

- [x] ★ Power row fires instantly — one icon-only click runs
      `systemctl poweroff`, no confirm; two-stage arm-then-confirm, and add a
      **Lock** button (lock is currently submap-only) (`Home.qml:839-861`)
- [x] ★ Color picker launches hyprpicker with the panel open and holding the
      focus grab — route through `Capture.withUiHidden()` like every button beside
      it (`Home.qml:734-739`)
- [x] Bluetooth: no connecting or failure state — failed connect looks like
      nothing happening; Wi-Fi already solved this inline
      (`BluetoothPage.qml:54-60,219-228`)
- [x] Tap a paired Bluetooth row to connect/disconnect; keep the expansion for
      Forget only (`BluetoothPage.qml:205-239`)
- [x] Esc from a detail page should go back Home before closing the panel
- [x] Apps mixer: per-stream mute (drag-to-zero loses the level) + app icons —
      the mute glyph exists on the same page's Output/Input rows
      (`AudioPage.qml:273-318`)
- [x] Media card: no track position, clicking art/title doesn't raise the
      player (`Home.qml:474-597`)
- [x] Brightness slider: no % readout (volume has one) (`Home.qml:362-387`)
- [x] KDE Connect chips give zero feedback — "Sent ✓" swap or toast
      (`KdeConnectPage.qml:219-238`)

### Launcher & Overview

- [x] ★ No frecency: empty query is alphabetical, launches never recorded —
      persist counts/timestamps, order empty list by frecency, boost ranked search
      (`services/Apps.qml:14,20-22,128-130`)
- [x] ★ Overview sits on Alt+Tab but only handles Escape — arrows/hjkl +
      Enter, digit workspace jumps, Tab to advance (`Overview.qml:172-175`)
- [x] Special-workspace windows filtered out of the overview (negative ids) —
      invisible, and no drag target to/from scratchpads (`Overview.qml:279-282`)
- [x] External-monitor thumbnails map against the overview monitor's geometry —
      second screen's workspaces render scrambled (`OverviewWindow.qml:31-42`)
- [x] Hover and keyboard selection are two different highlights; Enter launches
      the selected, not the hovered — make hover move `currentIndex`
      (`Launcher.qml:151-165`)
- [x] Launcher panel height snaps per keystroke — Behavior on height
      (`Launcher.qml:99-114`)
- [x] Overview: no window titles anywhere (two kitty windows indistinguishable)
      — hover tooltip; title data already fetched (`Overview.qml:53-63`)
- [x] Launcher: no overflow cue past 8 rows (fade or thin scrollbar); Up/Down
      dead-end at edges (wraparound, PageUp/Down)
- [x] Overview: no entrance animation (vs the launcher's spring); middle-click
      close and drag have zero affordance (corner × on hover, lift on drag)
- [x] Highlight fuzzy-match positions in results — computed then discarded
      (`services/Apps.qml:99-125`)

### Notifications

- [x] ★ Hover doesn't pause toast expiry — a toast can vanish mid-reach for
      its button (`NotificationPopups.qml:87-91`)
- [x] Critical notifications don't bypass DND — they file silently into
      history (`services/Notifs.qml:119-120`)
- [x] Toasts pop out of existence — add an exit animation to match the
      entrance (`NotificationPopups.qml:52-72`)
- [x] Icon fallback skips the desktop entry and goes straight to the generic
      bell — resolve `n.desktopEntry` via DesktopEntries first
      (`NotificationCard.qml:24-30`)
- [x] Flat mode zeroes the border — critical loses its only marking in the
      history list; add a dot or tinted summary
- [x] Action pill row can overflow the card (Row with no cap/wrap → Flow)
- [x] Body links render styled but clicking one dismisses the notification —
      `onLinkActivated` (`NotificationCard.qml:146-157`)
- [x] `transient` hint ignored — volume/progress spam pollutes history and the
      badge (`services/Notifs.qml:111-121`)

### Clipboard / OSD / Capture

- [x] ★ Record pill's audio toggles animate mid-recording but the audio graph
      is built once at launch — disable while recording
      (`RecordOverlay.qml:322-334`)
- [x] Second-monitor record overlay: duplicate functional pill clamps to the
      other screen's edge, shade bands dim it in stray strips — gate on region
      intersection (`RecordOverlay.qml:69-171`)
- [x] Armed record state is mouse-only — Enter=start, Esc=disarm; the keybind's
      second press starts rather than cancels (`Capture.qml:229-236`)
- [x] Clipboard deletion undiscoverable (Shift+Delete / middle-click, zero
      affordance) — hover-revealed × on rows
- [x] Truncated clipboard entries aren't searchable by their visible text —
      search scores the 100-char preview only (`services/Clipboard.qml:80-88`)
- [x] Large preview for the highlighted image entry — 58px thumbs are
      indistinguishable after a screenshot session (`ClipItem.qml:92-136`)
- [x] Volume OSD doesn't say which output device it's driving —
      `Audio.sink.description` is right there (`OsdPanel.qml:156-205`)
- [x] OSD floats visually over the launcher/clipboard panels (same
      bottom-center band) — suppress or raise while a panel is open
- [x] Full-screenshot 3s countdown can't be cancelled — second keypress or Esc
      aborts, hint it in the label (`Capture.qml:164-174,271-297`)
- [x] First clipboard open flashes "Clipboard is empty" while cliphist is
      still listing — loading flag (`ClipboardHistory.qml:138`)

### Cross-cutting

- [x] ★ Visible surfaces follow focus across monitors: toasts, OSD, launcher,
      clipboard, overview all bind `screen:` live to `Hyprland.focusedMonitor` —
      a toast you're reading teleports when the cursor crosses. Latch the screen
      when shown. (`NotificationPopups.qml:16`, `OsdPanel.qml:69`,
      `Launcher.qml:54`, `ClipboardHistory.qml:64`, `Overview.qml:98`)
- [x] ★ Keep Awake: no bar indicator once the panel closes (only consumer is
      the invisible IdleInhibitor) _and_ it resets on every shell reload — the one
      toggle sibling not in `PersistentProperties` (`services/Idle.qml:16`,
      `Bar.qml:41-44`)
- [x] ASUS profile/charge-limit writes that fail snap back with no message —
      the GPU path already notifies; compare settle read vs optimistic value
      (`services/Asus.qml:40-74`)

## Features

### Bar & glanceability

- [x] Calendar popout on the clock — the clock is the only inert bar module;
      one new Popouts Component, pure JS Date. Natural home for a weather line
      (open-meteo via the KdeConnect-style poll pattern)
- [x] Now-playing bar module (MPRIS) — the Control Center media card exists;
      pause is two clicks away
- [x] VPN/Tailscale presence badge on the wifi glyph (backend exists; needs a
      slow background poll)
- [x] Shared hover tooltip component — battery ETA, SSID+strength, tray
      titles, mic users are all computed but unreachable without clicks
- [x] Recording chip in the bar (blinking dot + elapsed, click to stop) — also
      the only indicator a _full-screen_ recording would have
- [x] Reveal bar over fullscreen via a hot top-edge strip
- [x] Focused-app title in the bar's empty center
- [x] Brightness scroll gesture mirroring the volume one

### Power & system

- [x] Low-battery notifications + critical action — today's entire story is
      the bar tinting red at 15%; the shell _is_ the notification daemon
- [x] Auto power-profile on plug/unplug — Power.set, UPower state, and the
      confirming OSD all exist, unconnected
- [x] Night light — no gamma tooling anywhere in the repo; small hyprsunset
      service + a third Focus tile.
      **Needs `pacman -S hyprsunset`** — the tile says so until it's installed.
- [x] Display page in Control Center — the monitor scripts (Super+Ctrl+M/E/L,
      eDP toggle) are keybind-only; the eDP toggle has a known recovery footgun
- [x] Submap indicator OSD — the power submap runs blind; the bind already
      carries the "(l)ock (e)xit…" description string
- [x] Supervise the shell: systemd user unit, Restart=on-failure — a crash
      silently takes bar, launcher, OSD, and the notification daemon.
      **Needs enabling once**: `systemctl --user daemon-reload && systemctl --user
enable --now qshell.service` (the startup line already prefers it when it is).
- [x] Power-profile IPC target for a keybind (OSD feedback is already free)
- [x] Animation-scale / reduced-motion setting — one persisted multiplier over
      the Appearance duration tokens

### Notifications

- [x] Inline reply on chat cards — Quickshell supports the extension; the
      server just doesn't advertise it (`services/Notifs.qml:101-109`)
- [x] Large image previews on image-bearing cards — capture pipeline already
      puts the path on the card; recreates the macOS screenshot-thumbnail flow
- [x] `notifs` IPC target: DND toggle, clear, dismiss-latest — DND stops being
      mouse-only
- [x] Auto-DND while recording — `popupsHidden` covers only the capture
      moment; live wf-recorder sessions burn toasts into the video
- [x] History grouping by app (one chatty app drowns the rest)
- [x] Per-app muting — single choke point in `onNotification`
- [x] Drag-to-dismiss toasts (pairs with the exit animation)
- [x] Persist history across shell restarts (Settings JSON pattern; also fixes
      re-adoption restamping arrival times)

### Capture

- [x] Floating recent-capture thumbnail — corner PanelWindow, click to open,
      lingers a few seconds; the signature macOS interaction
- [x] Annotation via a `qshell-edit` notification action launching
      satty/swappy — few lines in `lib/capture.sh` given the action plumbing
- [x] Full-screen recording entry point — `Capture.recordFull()` is fully
      implemented and has **no caller anywhere**
- [x] Pause/resume — wf-recorder 0.6.0 has **no** SIGUSR1 handler (the signal
      kills it and takes the unfinalised file), so pause closes the current segment
      and stop concatenates them losslessly. Pill button, bar chip right-click,
      Ctrl+Shift+7; dot goes solid while paused
- [x] Auto idle-inhibit while recording — one `||` on the bar's IdleInhibitor;
      hypridle can currently dim/lock mid-take, into the clip

### Launcher

- [x] Window search — Super+Shift+W still shells out to wofi+jq, the last
      daily surface that isn't qshell; toplevels/icons/scorer/dispatch all in-tree.
      Now the `/` mode, ordered by a real focus-history stack
      (`services/Windows.qml`), and it pulls a scratchpad up with the window
- [x] Calculator + run-command rows (math eval when the query parses; `Run:`
      as last resort instead of "No matches") — a recursive-descent parser, not
      `eval()` over arbitrary typed text
- [x] Command palette (`>` prefix): theme set (first UI for it), capture,
      power profiles, session verbs. The destructive three arm before they fire
- [x] Desktop-entry actions / jump lists ("New Private Window") — DesktopEntry
      exposes them, never surfaced. Findable by the app's name _or_ the
      action's own words
- [x] Emoji picker as a `:` prefix mode over an embedded table, wl-copy on
      accept — `data/emoji.json` is the emoji font's cmap ∩ the UCD, loaded
      lazily, recents and the everyday set first
- [x] True MRU Alt-Tab cycling in the overview (needs an MRU stack off
      activewindow events; release-to-commit can come later) — Tab walks the
      focus history, arrows keep the spatial ring
- [x] A `?` button in the search field naming every mode and key — the
      prefixes are the whole point and nothing on screen said they existed

### Clipboard

- [x] UI and functionality should be an copy of the mac os app Paste as much as possible. https://pasteapp.io/
      — a wide strip of cards along the bottom: source app + time across the
      top, the content at a readable size in the middle, kind + meta along the
      bottom; kind chips, a key legend, hover/arrow selection. Attribution
      needed a new writer (`scripts/clip-store.sh`), since cliphist records
      neither the app nor a timestamp. Not copied: named pinboards, sync,
      rules, per-app exclusions
- [x] Paste-on-select — `hyprctl dispatch sendshortcut CTRL,V,` after the
      focus grab clears; settings flag (terminals want Ctrl+Shift+V). Aimed at
      the window by address rather than at "whatever has focus", and fired off
      wl-copy's own exit rather than a guessed delay
- [x] Pinned entries (PersistentProperties precedent in Capture.qml) that
      survive screenshot churn and `cliphist wipe` — a pin keeps its own copy
      of the bytes, because every name cliphist has for an entry dies with it
- [x] Clear-all button — `Clipboard.wipe()` exists with no UI caller; confirm
      step, destructive styling. Pins are not history and stay

### Networking

- [x] Wi-Fi disconnect/forget — only way off a network today is toggling
      Wi-Fi entirely; wrong saved password has no recovery path (nmcli pattern
      proven in `Vpn.qml`). Used Quickshell's own Network.disconnect()/forget()
      instead; Forget arms before it fires, and takes the password row with it
- [x] Tailscale exit-node picker / device list — the service already runs
      `tailscale status --json`; drop `--peers=false` and the data's all there.
      Exit-node writes share the toggle's settle-poll, so a dismissed polkit
      prompt still reports as a failure

### Theming & session

- [x] Rosé Pine theme entries — shell ships only catppuccin-latte/mocha while
      everything around it is Rosé Pine; `Theme.qml` is data-driven, pure palette
      work. Sixteen themes now: Rosé Pine (main/moon/dawn), Dracula, Nord, Tokyo
      Night (night/day), Gruvbox, Everforest, Kanagawa, and the two missing
      Catppuccins. The picker is the launcher's `#` mode, with swatches painted
      in each theme's own colours — sixteen chips in a 340px panel is 18px each
- [x] Screen-sharing privacy light — portal screencasts appear as PipeWire
      video nodes; same pattern as `micUsers`, third Light + "shared with <app>".
      The brief's premise was wrong and that was the finding: both portal
      backends here publish the cast as `Video/Source`, the *same* class as the
      webcams, so what discriminates is the v4l2 tail the cameras drag behind
      them. Verified against a synthetic PipeWire stream, not a real cast —
      `debug screencast` exists to close that gap
- [x] Settings page (or `settings` IPC) — 5 of 6 settings.json keys are
      hand-edit-only despite live reload already working. Twelve of thirteen
      exposed now; numeric setters stage in memory and debounce the file write,
      since a slider drag would otherwise rewrite settings.json every frame.
      The panel widens for this page only
- [x] Home tiles: mic kill-switch (subtitle = `micUsers`), Tailscale/VPN
      toggle; keybinds for the Control Center pages (IPC verbs exist, unbound).
      Tailscale got the tile; NM VPNs are a list and a tile can't choose from
      one. Pages went to a `control` submap rather than four more combos
- [x] External-monitor brightness via DDC — slider/OSD/Fn keys silently affect
      only the laptop panel when the external is connected (ddcutil needs
      debouncing). `Brightness.display` now routes on the focused monitor and
      falls back to brightnessctl for everything that isn't a DDC display.
      **Untested against real hardware** — no external monitor has been attached
      since it was written; `debug ddc` reports what it found

### Theming fallout (found by an audit of the roster, 2026-08-05)

- [x] Light themes drew near-black bar glyphs on transparent chrome — a light
      palette's red *is* dark, and the bar's 75%-black drop shadow exists to
      make light glyphs pop, so it buried them. Latte's critical-battery glyph
      measured 0.14 relative luminance against its own 1.00 barFg. Light themes
      now take barOk/barWarn/barUrgent/barAwake from their family's dark variant
- [x] The charging bolt was `Theme.accentFg` on a `barOk` fill — a contrast
      guarantee made against `accent`, borrowed for a colour it has no
      relationship to. 1.49:1 in latte. Now `Theme.contrastFg(fill)`, worst case
      5.13:1 across all sixteen
- [x] `wsUrgentFg` was defined by every theme and read by none: the "+n"
      overflow count sat on the urgent fill in bar chrome (1.34:1 in mocha), and
      an urgent empty workspace drew its squircle outline in `wsUrgentBg` — the
      colour of the fill underneath it
- [x] Launcher emoji glyphs inherit `Theme.barFg` and vanish on light themes —
      colour-emoji survive because the font ignores `Text.color`, the ~168
      text-presentation ones don't (was also listed under Keybinds below)
- [ ] `RecordStatus.qml:47,61,88` — white dot and white bold timer on a
      `barUrgent` pill, which is a pastel by design in every dark theme: 2.32:1
      in mocha, below 3.5:1 in 9 of 16. Broken today, not new. Its `StateLayer`
      hover wash is `Theme.barFg` on the same pale pill, so hover is invisible too
- [ ] `RecordOverlay.qml:230,396,407,415` — Start/Pause/Stop take
      `Theme.ok/warn/urgent` as their *hover* fill under hardcoded white labels.
      White on `ok` is 1.37:1 in dracula, 1.49 in mocha; the Stop label
      disappears the moment you point at it, in all 12 dark themes. The pill is
      deliberately theme-independent, so these want fixed saturated tints
- [ ] `catppuccin-latte`'s surface `ok` (2.96:1) and `warn` (2.31:1) on
      `surfaceBg` are below the 3:1 floor for status text. Left at upstream
      Catppuccin values on purpose — diverging would make the one theme people
      compare against other Catppuccin apps the odd one out. Revisit if it bites

## Second pass (2026-08-04)

Everything above having landed, a second full-shell review — one reviewer per
surface, each finding re-read against the code by a skeptic that threw six out.
Nothing here restates a box above; several items exist _because_ of the first
pass, where one surface got a fix and its sibling didn't. ★ = highest daily-use
payoff.

### Bar

- [ ] ★ Wi-Fi glyph and its own tooltip contradict each other whenever Ethernet
      is up — `icon` tests `!wifiEnabled` before `ethernet` while `summary()`
      tests ethernet first, so docked with Wi-Fi off the bar draws the dim
      crossed-out "no network" glyph while the tooltip says "Ethernet"; with
      both links up the SSID and strength are dropped
      (`WifiStatus.qml:31-37,41,141`)
- [ ] Nothing marks which module owns the open menu — `Popouts.current` is read
      only by the hover-slide guards, and `moduleHoverBg`/`moduleActiveBg` are
      dead tokens no one binds; `Theme.qml:90-93` already describes the tint as
      if it shipped (`Theme.qml:20-21,46-47,76-77`, `StateLayer.qml:42-46`)
- [ ] Privacy lights disclose on hover with no delay and no stand-down, shoving
      the right cluster sideways on a pass-through — they're the only child of
      `statusRow` with no `tooltip:`, so they miss BarTooltip's 450ms delay and
      its `!Overlays.any` guard (`PrivacyStatus.qml:34-43,51`, `Bar.qml:262-289`)

### Popout menus

- [ ] ★ Notifications "Clear" wipes persisted history on the first click, while
      every destructive sibling in the shell arms first — the clipboard's
      identically-labelled Clear ("Erase history?"), Wi-Fi Forget, the session
      buttons. History survives restarts now, so there is no undo
      (`NotifsMenu.qml:129-152`, `services/Notifs.qml:203-213,284-298`)
- [ ] Enabling Wi-Fi from inside the menu never kicks a scan — the only
      `rescan()` is in `Component.onCompleted` and early-returns while the radio
      is off, so the list settles on the completed-scan filler ("No other
      networks") instead of "Scanning…" (`WifiMenu.qml:171-177,191-196,678-684`,
      `services/Net.qml:68-75`)
- [ ] Tailscale's switch has no busy guard — `toggle()` fires unconditionally
      where `setExitNode()` in the same file opens with `if (busy || !up)`, and
      since StyledSwitch renders only its bound `checked` the knob doesn't move,
      so a second tap during the polkit window queues a second password prompt
      (`services/Tailscale.qml:85-95` vs `:98-112`)
- [ ] A failed weather refresh leaves the last reading on screen, unmarked —
      neither `code` nor `fetchedAt` is reset on failure, so the row that only
      renders `error` in the `!valid` branch shows hours-old weather as current,
      defeating the service's own `maxAge` (`services/Weather.qml:36,87-104,166-173`)
- [ ] The exit-node picker is a bare Repeater with no cap and no scroll, sitting
      between two lists that both clamp — and the popout surface is a constant
      `s(920)` that silently clips (`WifiMenu.qml:882-952` vs `:346,995`)
- [ ] Esc from an open disclosure tears down the whole panel — only CalendarMenu
      and ControlCenter implement `navBack`, so an armed Forget, an open PSK row,
      the exit-node picker and expanded tray submenus all skip the peel
      (`Popouts.qml:222-226`, `WifiMenu.qml:85-108`, `TrayMenu.qml:47-60`)
- [ ] Toasts are hidden while _any_ popout is open but their expiry keeps
      running — the per-card timer pauses for hover, exit, drag and reply, not
      for `win.hidden`, so notifications arriving while you read the calendar
      burn unseen (`Popouts.qml:30`, `NotificationPopups.qml:37,238-246`)
- [ ] Tray checkbox/radio entries render nothing when unchecked — the gutter is
      gated on `checkState !== Unchecked`, which is also every plain action's
      state, and the label margin keys off the same flag, so the one checked
      member of a radio group sits 18px right of its siblings
      (`TrayMenuEntry.qml:51-82`)

### Control Center

- [ ] ★ Sliders still take a fixed 4% per raw wheel event — `StyledSlider` ends
      in a bare `WheelHandler`, so a touchpad flick slams brightness, volume,
      mic and every per-app level end to end. `WheelDetent` was written for this
      exact bug and its comment says so (`StyledSlider.qml:73-75`)
- [ ] Muted output still prints a percentage over a full-accent slider — the
      per-app rows on the same page already dim the slider, dim the name and
      swap the readout for "mute" (`Home.qml:355-390`, `AudioPage.qml:76-104`
      vs `:350,367`)
- [ ] Night Light's tile is a live click target that can do nothing on this
      machine — hyprsunset is absent, so the handler is a guarded no-op while
      the tile keeps its pointer cursor, hover wash and ripple. Both fixes are
      in-repo: the media button's `enabled:` + `opacity: 0.35`, or the palette's
      omission (`Home.qml:88-92,312-323`)
- [ ] The Displays tile is a navigation target dressed as a toggle — same `Tile`
      as its three switch siblings, `active: false` hardcoded so its badge can
      never light, and no chevron, which every other drill-down in the panel has
      (`Home.qml:325-331`, `Tile` at `:73-128`)
- [ ] Display layout chips acknowledge nothing on tap and the result takes at
      least 900ms to land — the eDP chip one card down already does
      `flash("Toggling")`, and `Chip.flash()` is shared (`DisplayPage.qml:38-75`,
      `services/Displays.qml:42-45`)
- [ ] The colour picker lives in the Record row, so mid-recording a row headed
      "Recording · 0:12" reads Stop / Pause / Color — move it into the
      screenshot row or give it its own slot (`Home.qml:828-885`)
- [ ] KDE Connect's Refresh is the one action chip on the page with no
      acknowledgement, and the list almost always comes back identical, so it
      reads as dead (`KdeConnectPage.qml:64-69` vs `:221-249`)
- [ ] Per-app mixer names sit on two different rails depending on whether the
      icon resolved — reserve the slot and toggle only the pixels
      (`AudioPage.qml:328-333`)

### Launcher & Overview

- [ ] ★ The `/` window switcher opens preselected on the window you are already
      in, so its first Enter is a no-op — row 0 is the MRU head and the
      launcher's own grab doesn't disturb it; start at row 1 in `/` mode, the
      way Alt+Tab does (`services/Search.qml:220-254`, `Launcher.qml:52,368-371`)
- [ ] Overview paints two competing accent highlights — hover and keyboard
      selection both light a thumbnail, and different keys act on each (Enter
      takes `selWin`, click takes the hovered one). The launcher already solved
      this by making hover move `currentIndex` (`OverviewWindow.qml:114-125`)
- [ ] Overview Up/Down duplicate Left/Right — all eight nav keys step ±1 through
      a flat list, so nothing ever moves _down_ a row in a UI whose whole shape
      is a grid (`Overview.qml:321-324`)
- [ ] The overview's keyboard vocabulary is invisible: Tab/arrows/hjkl/digits
      all handled, nothing on screen says so, while both sibling panels grew a
      legend and a `?` mode for exactly this (`Overview.qml:313-335`)
- [ ] An armed destructive command keeps its red "Enter again" after the
      selection moves off it — `armed` is never cleared by Up/Down, PageUp/Down
      or hover-select, so the confirm prompt sits on a row Enter will not fire
      (`Launcher.qml:78-81,368-376`, `ResultItem.qml:109,124`)
- [ ] Per-mode placeholders never render and the `>` one is wrong — the only
      call site is gated on an empty field, which no mode can have (the prefix
      is in it), and the unreachable Commands string describes `!`
      (`Launcher.qml:404-411`, `services/Search.qml:32-37,79-96`)
- [ ] A failed emoji load shows "Loading emoji…" forever _and_ wedges `ensure()`
      — it re-assigns `table.path` the value it already holds, so no
      `pathChanged`, no re-read, and `loading` stays true for the session
      (`services/Emoji.qml:19-32,68-81`)
- [ ] Overview click targets keep the arrow cursor while the 15px × inside them
      turns into a hand — every other clickable surface in the shell inherits
      the pointer from StateLayer (`OverviewWindow.qml:158-163,237-241`,
      `Overview.qml:405-408,529-532`)
- [ ] Overview scratchpad chips stop at 5 icons with no "+n" — the bar's
      workspace slot solved the identical honesty problem, comment and all
      (`Overview.qml:507-527` vs `WorkspaceSlot.qml:94-118`)

### Notifications & OSD

- [ ] ★ Three of the four ways a toast leaves the screen erase it from history
      and the fourth doesn't — ×, body-click and swipe all route to
      `n.dismiss()`, while letting it expire keeps it. Nothing distinguishes
      them, so the fastest way to clear a toast is also the one that loses it
      (`NotificationPopups.qml:129,157-158`, `NotificationCard.qml:66-75`,
      `services/Notifs.qml:140-153`)
- [ ] Every OSD dismissal morphs the pill into a volume readout while still
      fully opaque — `Osd.kind` is cleared at the _start_ of the hide, so a
      brightness pill swaps sun→speaker and animates its fill to the audio
      volume on the way out (`OsdPanel.qml:38-48,120-131`, `services/Osd.qml:80-90`)
- [x] The submap OSD pill is wider than its own window and clipped at both ends
      — the power hint measures ~544px inside a fixed `s(420)` surface, with no
      cap, elide or wrap (`OsdPanel.qml:89,122,249-258`). The window now sizes
      itself from the pill rather than the other way round, capped to the screen
      with the label eliding only past that. Forced by the new `control` submap,
      whose hint is longer still
- [ ] The newest toast can be drawn below the bottom edge of the popup surface —
      fixed `s(740)` height, top-anchored Column, up to five cards of unbounded
      height (three image-bearing cards already overflow)
      (`NotificationPopups.qml:47,63-76`)
- [ ] Restored history cards look live but have lost every action — `ghostFor`
      hardcodes `actions: []` and `serialize` never writes them, so after a
      restart a screenshot notification still shows its thumbnail and path but
      no Open/Annotate/Reveal, which would still work, and nothing marks the
      card as archived (`services/Notifs.qml:240-281`, `scripts/lib/capture.sh:26-37`)
- [ ] Typing an inline reply in the notification centre drives the list behind
      it — nothing gates `replyBox` on flat mode, and the field swallows none of
      Up/Down/Enter the way the Wi-Fi PSK field explicitly does
      (`NotificationCard.qml:412-444`, `WifiMenu.qml:552-558`)
- [ ] History rows give no hover feedback though the same list highlights the
      keyboard-selected row — flat mode paints `"transparent"` and changes only
      the cursor, even on rows where a click does something
      (`NotificationCard.qml:205-220`, `NotifsMenu.qml:338-344`)

### Clipboard & capture

- [x] ★ A copy or pin that fails does so silently — `take()` closes the panel
      the instant the copy is _launched_ and `copier.onExited` has no failure
      branch, so an evicted id or a missing pin payload ends with the panel
      closed, the clipboard unchanged and nothing on screen
      (`services/Clipboard.qml:461-485`, `ClipCard.qml:100-103`). Both paths now
      report through notify-send, and a failed copy re-lists the history that
      lied to it
- [x] On a pinned card the × and the unpin button beside it do the same thing —
      and neither deletes: unpinning re-exposes the source history row, so the
      entry reappears further along the strip (`ClipCard.qml:91-98,395-429`).
      The × now means gone: `Clipboard.forget()` drops the pin _and_ the row it
      was standing in for
- [x] An image copied as a _path_ renders a thumbnail with an empty footer —
      `showsThumb` both hides the filename column and routes `meta` into the
      binary branch, whose fields are empty for a path entry, so the card is a
      picture with a blank bottom row (`ClipCard.qml:46,74-78,310-314`). Only
      actual bytes take the binary branch now; a path shows its filename
- [x] A colour entry never shows the hex it holds — the swatch replaces the body
      text and `meta` falls through to "7 characters", so two similar greens are
      indistinguishable (`ClipCard.qml:74-84,299-308,349`). The value is drawn
      on the swatch, in black or white by its luminance
- [x] The card strip is the only list in the shell with no scroll indicator, and
      an empty query returns the whole pool unsliced — the launcher and the
      notification list both grew the same 3px thumb in the first pass
      (`ClipboardHistory.qml:451-496`). Same thumb, turned on its side, plus an
      item count in the header. The pool stays whole on purpose: the ListView
      only builds what is near the viewport, and a silent cap would put entry
      200 out of reach of everything except search
- [x] The record pill loses every button during the launch window —
      `startPending` makes `armed` false before `recording` turns true, so from
      `startRecorder()` until the 1s poll the pill is a grey dot with no control
      and no "Starting…", while its audio toggles stay live
      (`RecordOverlay.qml:277,376-409`). It says "Starting…" now, and the
      toggles lock with the flags they have already handed over

### Keybinds & cross-cutting

- [ ] ★ The colour-picker keybind still runs raw hyprpicker — Super+Shift+P
      execs `hyprpicker | wl-copy` directly, so it gets none of
      `Capture.pickColor()`: no `withUiHidden()` (the bar and toasts stay up for
      the magnifier to sample, and an open popout's focus grab eats the click),
      no "Copied" toast, no deadman. The Control Center button was fixed; the
      keybind wasn't (`config/hypr/lua/apps.lua:90`, `services/Capture.qml:175-185`)
- [ ] Six keybinds are missing from the Super+/ cheatsheet because their comment
      has no space before `--` — the overlay's `_label()` regex needs `\s--`, so
      fullscreen, the colour picker, move-to-scratchpad and three more silently
      vanish from the list that exists to teach them
      (`config/hypr/lua/binds.lua:39,47,48,84,98,101`, `bin/keycheat-overlay.py:64-66`)
- [ ] Super+Shift+C is labelled "toggle bar" in the cheatsheet and restarts the
      entire shell — bar, launcher, clipboard, OSD, capture overlays and the
      notification daemon, with a second press restarting again rather than
      restoring anything (`config/hypr/lua/binds.lua:40`, `apps.lua:54`)
- [x] Launcher emoji glyphs inherit `Theme.barFg` (white) and vanish on the
      default light theme — colour-emoji entries survive because the font
      ignores `Text.color`, but the 168 text-presentation ones (‼ ⁉ ™ ℹ ↔ ⌨ …)
      do not (`ResultItem.qml:91-99`, `StyledText.qml:5`). Now `surfaceFg`;
      there are five light themes to vanish on rather than one
- [ ] Bluetooth "Forget" unpairs on a single tap while its Wi-Fi twin — same
      verb, same `Chip` component, also irreversible — arms first and says
      "Sure?" (`BluetoothPage.qml:310-318` vs `WifiMenu.qml:110-131,265-271`)
- [ ] A stray NUL byte in `NotificationCard.qml:114` makes the repo's grep treat
      the shell's most-shared component as binary and skip it silently — a
      search for a symbol defined there returns nothing, with no "binary file
      matches" notice. Runtime behaviour is unaffected

### Suggested second-pass sequence

1. The three ★ losses of data or work: toast dismissal semantics, the
   notification Clear with no arm, the silent clipboard copy failure
2. The two ★ everyday frictions: `StyledSlider` on `WheelDetent`, and `/` mode
   opening on the window you are already in
3. The keybind row — colour picker through the shell, the cheatsheet's six
   missing binds, and the mislabelled restart — all of it one file each
