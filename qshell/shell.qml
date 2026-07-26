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
import qs.modules.launcher
import qs.modules.notifications
import qs.modules.osd
import qs.modules.overview

ShellRoot {
    Bar {}

    Launcher {}

    ClipboardHistory {}

    RecordOverlay {}

    NotificationPopups {}

    OsdPanel {}

    Overview {}

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

        function record(): string {
            Capture.toggleRecording();
            return Capture.recording ? "stopping" : "starting";
        }
    }

    // `qs -c qshell ipc call debug net` — introspection while developing.
    IpcHandler {
        target: "debug"

        function backlight(): string {
            return `display=${Math.round(Brightness.display * 100)}% kbd=${Brightness.kbd}/${Brightness.kbdMax} kbdHw=${Brightness.kbdHw} available=${Brightness.kbdAvailable}`;
        }

        function privacy(): string {
            return `mic inUse=${Audio.micInUse} muted=${Audio.micMuted} users=${JSON.stringify(Audio.micUsers)}\ncamera inUse=${Camera.inUse} handles=${Camera.users}`;
        }

        function scan(active: bool): string {
            if (!Net.wifi)
                return "no wifi device";
            Net.wifi.scannerEnabled = active;
            return `scanner=${active}`;
        }

        function kdectest(): string {
            Quickshell.execDetached(["sh", "-c", "kdeconnect-cli --list-devices > /tmp/claude-1000/kdec.out 2>&1"]);
            return "spawned";
        }

        function kdec(): string {
            KdeConnect.refresh();
            return `${JSON.stringify(KdeConnect.devices)} raw=${KdeConnect.lastRaw.slice(0, 300)}`;
        }

        function wsicons(): string {
            return Hyprland.toplevels.values.map(t => {
                const c = t.lastIpcObject?.class ?? "<null>";
                const n = DesktopEntries.heuristicLookup(c)?.icon;
                const src = (n && Quickshell.iconPath(n, true)) || Quickshell.iconPath("application-x-executable", true) || "";
                return `ws${t.lastIpcObject?.workspace?.id} class=${c} icon=${n} src=${src}`;
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
