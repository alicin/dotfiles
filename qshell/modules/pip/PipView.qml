import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services

// Picture-in-Picture (elementary OS's): a live, always-on-top, scaled-down view
// of one open window, so a build or a log stays watchable from inside something
// else. Same mechanism as the overview's thumbnails — hyprland-toplevel-export
// through ScreencopyView — pointed at one window instead of all of them.
//
// Named PipView rather than Pip: shell.qml imports both qs.services and
// qs.modules.pip, and two types called Pip would be ambiguous there.
//
// Toggle: `qs -c qshell ipc call pip toggle` (Super+Shift+I), or from the
// launcher's `/` windows mode. State lives in services/Pip.qml.
Scope {
    id: root

    IpcHandler {
        target: "pip"

        // An omitted trailing string arrives as "", which `capture record` and
        // `notifs mute` already rely on — so no argument means "the focused
        // window".
        function toggle(address: string): string {
            return Pip.toggle(address) ? `pinned ${Pip.title}` : "unpinned";
        }

        function pin(address: string): string {
            return Pip.pin(address) ? `pinned ${Pip.title}` : `no window to pin`;
        }

        function unpin(): string {
            const had = Pip.active;
            Pip.unpin();
            return had ? "unpinned" : "nothing pinned";
        }

        // No argument cycles, so one bind reaches all four positions.
        function corner(which: string): string {
            const all = ["topleft", "topright", "bottomleft", "bottomright"];
            const w = (which || "").toLowerCase().replace(/[^a-z]/g, "");
            Pip.corner = all.includes(w) ? w : all[(all.indexOf(Pip.corner) + 1) % all.length];
            Pip.posX = -1;
            Pip.posY = -1;
            return Pip.corner;
        }

        function size(v: string): string {
            const named = ({
                    small: 0.16,
                    medium: 0.24,
                    large: 0.34
                });
            const n = named[(v || "").toLowerCase()] ?? parseFloat(v);
            if (!isFinite(n) || n <= 0)
                return `unknown size "${v}" — small / medium / large, or a fraction`;
            // Clamped here rather than trusted: this is reachable from a shell
            // command, and a fraction of 40 is a card larger than the screen
            // with its close button off the edge.
            Pip.fraction = Math.max(0.08, Math.min(0.6, n));
            return `${Pip.fraction}`;
        }

        function status(): string {
            if (!Pip.active)
                return "nothing pinned";
            return `address=${Pip.address} title="${Pip.title}" corner=${Pip.corner} fraction=${Pip.fraction} alive=${!!Pip.toplevel}`;
        }
    }

    LazyLoader {
        // Nothing exists until something is pinned: an always-mapped overlay
        // surface would sit above every window all day for the sake of a card
        // that is usually not there.
        active: Pip.active

        PanelWindow {
            id: win

            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0

            // Screen-sized, and therefore CONSTANT. The card is positioned and
            // resized inside this surface and never touches it, so no animated
            // child can reach the Wayland surface — which is the trap the OSD
            // fell into, where deriving implicitWidth from an animating pill
            // resized the layer surface every frame and made rules.lua fade
            // `qshell:.*` underneath the real animation.
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            WlrLayershell.namespace: "qshell:pip"
            WlrLayershell.layer: WlrLayer.Overlay
            // Never takes keyboard focus: this is a thing you glance at, and a
            // card that stole focus would eat the keystrokes meant for whatever
            // you are actually working in.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // Only the card is clickable; the rest of the screen-sized surface
            // is not there as far as input is concerned.
            mask: Region {
                item: card
            }

            PipCard {
                id: card
            }
        }
    }
}
