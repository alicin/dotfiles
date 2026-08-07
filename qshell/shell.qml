// Dark variant on purpose: its SYMBOLIC icons (what tray apps like nm-applet
// and blueman send) are light-colored, matching the bar's white fg — the dawn
// variant paints them dark rose-pine ink. Colored app icons are identical.
//@ pragma IconTheme rose-pine-icons

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Services.Pipewire
import qs.config
import qs.services
import qs.modules.bar
import qs.modules.capture
import qs.modules.clipboard
import qs.modules.control
import qs.modules.gestures
import qs.modules.keycheat
import qs.modules.launcher
import qs.modules.notifications
import qs.modules.osd
import qs.modules.osk
import qs.modules.overview
import qs.modules.pip

ShellRoot {
    id: shellRoot

    // A singleton nobody references is never instantiated; this one's whole
    // point is to sit and watch the theme setting, so it gets its reference
    // here. (Every other service is referenced by some panel already.)
    readonly property var themeSync: ThemeSync

    Bar {}

    Launcher {
        id: launcherPanel
    }

    ClipboardHistory {
        id: clipboardHistory
    }

    RecordOverlay {}

    NotificationPopups {}

    OsdPanel {}

    Overview {}

    // Picture-in-Picture: a live thumbnail of one window, pinned above
    // everything. Nothing is mapped until something is pinned.
    PipView {}

    // Shortcut cheat sheet, generated from ~/.config/hypr/lua/binds.lua.
    // Was bin/keycheat-overlay.py (GTK4, hardcoded Mocha palette); it is a shell
    // surface now so it follows the theme.
    KeyCheat {}

    // The standalone Settings window (macOS System Settings shaped) — a
    // LazyLoader that only materialises while SettingsUi.open is true.
    SettingsWindow {}

    CaptureThumb {}

    // Touchscreen edge swipes. Nothing but three input strips, and only in
    // touch mode — see modules/gestures/EdgeSwipes.qml.
    EdgeSwipes {}

    // Last, deliberately: the on-screen keyboard sits on the Overlay layer and
    // has to draw above the panels you would type into. Same-layer surfaces
    // stack in creation order.
    OskPanel {}

    // Brightness media keys. Volume needs nothing here — Pipewire signals every
    // change, whoever made it — but the kernel gives no such signal for the
    // backlights, so the keys come through the shell and it raises the OSD on
    // the press instead of whenever a poll next runs. Hyprland falls back to
    // brightnessctl/asusctl when the shell isn't up (see hypr's apps.lua).
    IpcHandler {
        target: "brightness"

        function up(): string {
            Brightness.stepDisplay(1);
            Osd.show("brightness");
            return "ok";
        }

        function down(): string {
            Brightness.stepDisplay(-1);
            Osd.show("brightness");
            return "ok";
        }

        function kbdUp(): string {
            Brightness.stepKbd(1);
            Osd.show("kbd");
            return "ok";
        }

        function kbdDown(): string {
            Brightness.stepKbd(-1);
            Osd.show("kbd");
            return "ok";
        }
    }

    // `qs -c qshell ipc call capture shot window` — the Control Center's capture
    // row over IPC, so these can be bound to keys (and driven in a test).
    IpcHandler {
        target: "capture"

        function shot(mode: string): string {
            if (!["area", "window", "full"].includes(mode))
                return `unknown mode "${mode}" — area / window / full`;
            Capture.shoot(mode);
            return "ok";
        }

        // `record` toggles an area recording (the Ctrl+Shift+5 bind);
        // `record full` starts one on the whole screen — Capture.recordFull()
        // was fully implemented and had no caller anywhere.
        function record(mode: string): string {
            // Read *before* the toggle: `recording` is owned by the pgrep poll
            // and doesn't flip synchronously, so reading it after reports the
            // state we just left rather than the action taken.
            const wasLive = Capture.recording || Capture.paused;
            if (mode === "full" && !wasLive) {
                Capture.recordFull();
                return "starting";
            }
            Capture.toggleRecording();
            return wasLive ? "stopping" : "starting";
        }

        // Region OCR and QR decode. Both take a selection and put the answer on
        // the clipboard, so they belong with the other one-shot region verbs
        // rather than in a target of their own.
        function ocr(): string {
            Capture.extractText();
            return "ok";
        }

        function qr(): string {
            Capture.scanQr();
            return "ok";
        }

        function pause(): string {
            if (!Capture.recording && !Capture.paused)
                return "not recording";
            Capture.togglePause();
            return Capture.recording ? "pausing" : "resuming";
        }

        // Called by the capture scripts once a file is on disk, so a
        // keyboard-driven capture gets the floating thumbnail too.
        function saved(path: string): string {
            Capture.saved(path);
            return "ok";
        }

        // Which audio sources get mixed into a recording. Persisted, so these
        // are a standing preference rather than a per-clip choice; the overlay
        // has the same two toggles.
        function audio(which: string): string {
            if (which === "mic")
                Capture.toggleMic();
            else if (which === "system")
                Capture.toggleSystem();
            else
                return `unknown source "${which}" — mic / system`;
            return `system=${Capture.recordSystem} mic=${Capture.recordMic}`;
        }

        // Called by the capture scripts themselves, not by a person: `done`
        // from their EXIT trap so the shell stops hiding its own toasts on
        // every path out, and `region` to hand back the geometry an area
        // recording was drawn on.
        function done(): string {
            Capture.finished();
            return "ok";
        }

        function region(geom: string): string {
            Capture.region(geom);
            return "ok";
        }
    }

    // `qs -c qshell ipc call notifs dnd` — DND, clearing and dismissing were
    // mouse-only, which made the one setting you want before a screen share
    // the one you had to open a menu for.
    IpcHandler {
        target: "notifs"

        function dnd(): string {
            Notifs.toggleDnd();
            return Notifs.dnd ? "on" : "off";
        }

        function clear(): string {
            const n = Notifs.count;
            Notifs.clearAll();
            return `cleared ${n}`;
        }

        function dismiss(): string {
            return Notifs.dismissLatest() ? "ok" : "nothing to dismiss";
        }

        function mute(app: string): string {
            if (!app)
                return `muted: ${Notifs.muted.join(", ") || "none"}`;
            Notifs.toggleMute(app);
            return Notifs.isMuted(app) ? `muted ${app}` : `unmuted ${app}`;
        }
    }

    // `qs -c qshell ipc call power cycle` — the OSD already announces every
    // profile change, whoever made it, so a keybind gets its feedback free.
    IpcHandler {
        target: "power"

        function get(): string {
            return Power.label(Power.profile);
        }

        function cycle(): string {
            const all = Power.all;
            const i = all.indexOf(Power.profile);
            Power.set(all[(i + 1) % all.length]);
            return Power.label(Power.profile);
        }

        function set(name: string): string {
            const want = name.toLowerCase().replace(/[^a-z]/g, "");
            const match = Power.all.find(p => Power.label(p).toLowerCase().replace(/[^a-z]/g, "") === want);
            if (match === undefined)
                return `unknown profile "${name}" — ${Power.all.map(p => Power.label(p)).join(", ")}`;
            Power.set(match);
            return Power.label(match);
        }
    }

    // `qs -c qshell ipc call debug net` — introspection while developing.
    IpcHandler {
        target: "debug"

        function backlight(): string {
            return `display=${Math.round(Brightness.display * 100)}% kbd=${Brightness.kbd}/${Brightness.kbdMax} kbdHw=${Brightness.kbdHw} available=${Brightness.kbdAvailable}`;
        }

        function privacy(): string {
            return `mic inUse=${Audio.micInUse} muted=${Audio.micMuted} users=${JSON.stringify(Audio.micUsers)}\ncamera inUse=${Camera.inUse} handles=${Camera.users} apps=${JSON.stringify(Camera.apps)}\nscreencast active=${Screencast.active} apps=${JSON.stringify(Screencast.apps)}`;
        }

        // The screencast predicate was written without a real cast to look at
        // (see services/Screencast.qml) — this is how you check it against one:
        // start a share, run this, and the actual graph replaces the inference.
        function screencast(): string {
            return Screencast.dump();
        }

        function ddc(): string {
            return Ddc.dump();
        }

        function power(): string {
            return `profile=${Power.label(Power.profile)} pct=${Power.percent} charging=${Power.charging} known=${Power.known} warnedAt=${Power.warnedAt} auto=${Power.autoProfile} acProfile=${Power.label(Power.acProfile)} suspendAt=${Power.suspendAt} nightLight=${NightLight.available ? (NightLight.enabled ? NightLight.temperature + "K" : "off") : "unavailable"}`;
        }

        function overlays(): string {
            return `any=${Overlays.any} menus=${Overlays.menus} panels=${Overlays.panels} toasts=${Overlays.toasts} overview=${Overlays.overview} thumb=${Overlays.captureThumb}`;
        }

        // `qs ipc call debug search '>power'` — what the launcher would list,
        // without having to type into it.
        function search(query: string): string {
            const rows = Search.results(query);
            return `${rows.length} rows\n` + rows.slice(0, 12).map(r => `  ${r.kind}: ${r.name}${r.sub ? " — " + r.sub : ""}${r.badge ? "  [" + r.badge + "]" : ""}`).join("\n");
        }

        function osd(): string {
            return `kind="${Osd.kind}" submap="${Osd.submap}" label="${Osd.submapLabel}"`;
        }

        // Selection and scroll offset of the clipboard strip. Both survive a
        // close (the panel lives here, it is never destroyed), so "where does
        // it open?" is a real question with a real answer.
        function clip(): string {
            return clipboardHistory.debugState;
        }

        // Same reason as clip(): whether Enter fires comes down to
        // list.currentIndex, and -1 looks identical to 0 from outside.
        function launcher(): string {
            return launcherPanel.debugState;
        }

        function weather(): string {
            return `valid=${Weather.valid} loading=${Weather.loading} err="${Weather.error}" wanted=${Weather.wanted} ${Math.round(Weather.temp)}° ${Weather.label} hi=${Weather.high} lo=${Weather.low} place="${Weather.place}"`;
        }

        function displays(): string {
            return JSON.stringify(Displays.monitors);
        }

        function capture(): string {
            return `recording=${Capture.recording} paused=${Capture.paused} armed=${Capture.armed} geom="${Capture.regionGeom}" elapsed=${Capture.elapsedText} last="${Capture.lastCapture}"`;
        }

        function notifs(): string {
            return `count=${Notifs.count} unseen=${Notifs.unseen} popups=${Notifs.popups.length} dnd=${Notifs.dnd} lastSeen=${Notifs.lastSeenAt}`;
        }

        // What the newest notification actually carries — which hint an app
        // put its picture in decides whether a card grows a preview band.
        function notif(): string {
            const n = Notifs.list[0]?.n;
            if (!n)
                return "no notifications";
            return `app="${n.appName}" appIcon="${n.appIcon}" image="${n.image}" desktopEntry="${n.desktopEntry}"`;
        }

        function scan(active: bool): string {
            if (!Net.wifi)
                return "no wifi device";
            Net.wifi.scannerEnabled = active;
            return `scanner=${active}`;
        }

        function kdectest(): string {
            Quickshell.execDetached(["sh", "-c", "kdeconnect-cli --list-devices > /tmp/kdec.out 2>&1"]);
            return "spawned";
        }

        function kdec(): string {
            KdeConnect.refresh();
            return `${JSON.stringify(KdeConnect.devices)} raw=${KdeConnect.lastRaw.slice(0, 300)}`;
        }

        function wsicons(): string {
            return Hyprland.toplevels.values.map(t => {
                const pid = t.lastIpcObject?.pid ?? 0;
                const c = t.lastIpcObject?.class ?? t.wayland?.appId ?? "<null>";
                return `ws${t.workspace?.id} class=${c} pid=${pid} exe=${Apps.exeName(pid) || "-"} src=${Apps.toplevelIcon(t)}`;
            }).join("\n");
        }

        function icon(cls: string): string {
            const h = DesktopEntries.heuristicLookup(cls);
            const b = DesktopEntries.byId(cls);
            return `byId=${b?.id ?? "-"} icon=${b?.icon ?? "-"} | heuristic=${h?.id ?? "-"} icon=${h?.icon ?? "-"} | hPath=${h?.icon ? Quickshell.iconPath(h.icon, true) : "-"}`;
        }

        function audio(): string {
            return Pipewire.nodes.values.map(n => `${n.name} class=${n.properties["media.class"]} sink=${n.isSink} stream=${n.isStream} ready=${n.ready}`).join("\n");
        }

        function net(): string {
            const devs = Networking.devices.values.map(d => `${d.name} type=${d.type} wifi=${d instanceof WifiDevice} connected=${d.connected}`);
            const nets = Net.wifi?.networks.values.map(n => `${n.name} conn=${n.connected} known=${n.known} sig=${n.signalStrength}`) ?? ["<no wifi device>"];
            return `backend=${Networking.backend} wifiEnabled=${Networking.wifiEnabled}\ndevices:\n  ${devs.join("\n  ")}\nnetworks:\n  ${nets.slice(0, 8).join("\n  ")}`;
        }
    }

    // `qs -c qshell ipc call theme set catppuccin-mocha`
    IpcHandler {
        target: "theme"

        function get(): string {
            return Settings.theme;
        }

        function list(): string {
            return Theme.available.join("\n");
        }

        function set(name: string): string {
            if (!Theme.available.includes(name))
                return `unknown theme "${name}" — available: ${Theme.available.join(", ")}`;
            Settings.setTheme(name);
            return `theme set to ${name}`;
        }
    }
}
