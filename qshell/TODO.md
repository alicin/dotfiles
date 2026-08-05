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
      exposes them, never surfaced. Findable by the app's name *or* the
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

- [ ] UI and functionality should be an copy of the mac os app Paste as much as possible. https://pasteapp.io/
- [ ] Paste-on-select — `hyprctl dispatch sendshortcut CTRL,V,` after the
      focus grab clears; settings flag (terminals want Ctrl+Shift+V)
- [ ] Pinned entries (PersistentProperties precedent in Capture.qml) that
      survive screenshot churn and `cliphist wipe`
- [ ] Clear-all button — `Clipboard.wipe()` exists with no UI caller; confirm
      step, destructive styling

### Networking

- [ ] Wi-Fi disconnect/forget — only way off a network today is toggling
      Wi-Fi entirely; wrong saved password has no recovery path (nmcli pattern
      proven in `Vpn.qml`)
- [ ] Tailscale exit-node picker / device list — the service already runs
      `tailscale status --json`; drop `--peers=false` and the data's all there

### Theming & session

- [ ] Rosé Pine theme entries — shell ships only catppuccin-latte/mocha while
      everything around it is Rosé Pine; `Theme.qml` is data-driven, pure palette
      work
- [ ] Auto light/dark on a schedule (Timer + one settings key; chips row gets
      an Auto chip)
- [ ] Wallpaper switching tied to themes — hyprpaper is one hardcoded
      forest.jpg under a deliberately-transparent bar; apply via
      `hyprctl hyprpaper wallpaper`, persist per-theme
- [ ] Shell-drawn lock screen (WlSessionLock) — hyprlock.conf is a
      pre-rose-pine leftover; cheap interim: regenerate its colors from the active
      theme
- [ ] Screen-sharing privacy light — portal screencasts appear as PipeWire
      video nodes; same pattern as `micUsers`, third Light + "shared with <app>"
- [ ] Settings page (or `settings` IPC) — 5 of 6 settings.json keys are
      hand-edit-only despite live reload already working
- [ ] Home tiles: mic kill-switch (subtitle = `micUsers`), Tailscale/VPN
      toggle; keybinds for the Control Center pages (IPC verbs exist, unbound)
- [ ] Dock — every hard part is built (icon resolution, toplevel enumeration,
      reveal animations); absence may be deliberate, decide first
- [ ] External-monitor brightness via DDC — slider/OSD/Fn keys silently affect
      only the laptop panel when the external is connected (ddcutil needs
      debouncing)

## Suggested starting sequence

1. The `notifySnippet` bug
2. The six ★ small items: mic light, badge semantics, scroll detents, toast
   hover-pause, body-click behavior, record-toggle honesty
3. Calendar popout + low-battery warnings

That batch is mostly one-file changes and covers what the shell currently
_gets wrong_ rather than merely lacks.
