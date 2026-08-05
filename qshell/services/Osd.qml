pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// What the on-screen display is showing, and for how much longer.
//
// Volume, mic mute and the power profile are *reactive*: Pipewire and
// power-profiles-daemon signal every change no matter who made it, so a media
// key, pavucontrol, a headset button or `powerprofilesctl` all raise the OSD
// with nothing routed through the shell. Brightness has no such signal — the
// kernel won't tell us — so those keys call in over IPC and `show()`.
Singleton {
    id: root

    // "" | "volume" | "mic" | "brightness" | "kbd" | "power" | "countdown"
    //    | "submap"
    property string kind: ""

    // The Hyprland submap currently active, "" outside one. A submap silently
    // rebinds the whole keyboard — the power one turns `p` into poweroff — and
    // until now the only sign you were in one was that keys did unexpected
    // things.
    property string submap: ""

    // The keys each submap answers to. Hyprland's `submap` event carries only
    // the name, and the bind that enters it carries the description — which
    // lives in the config, not in the event, so it's mirrored here.
    // (config/hypr/lua/submaps/power.lua)
    readonly property var submapHints: ({
            power: "(l)ock  (e)xit  (r)eboot  (p)oweroff  (s)uspend  ·  Esc"
        })

    readonly property string submapLabel: root.submap === "" ? "" : (root.submapHints[root.submap] ?? root.submap)

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name !== "submap")
                return;
            // Leaving a submap sends an empty payload.
            root.submap = event.data ?? "";
            if (root.submap !== "")
                root.show("submap");
            else if (root.kind === "submap")
                root.hide();
        }
    }

    // Pipewire's first notifications are the sink coming up, not a person
    // pressing anything.
    property bool armed: false

    // The launcher and clipboard picker occupy the OSD's bottom-center spot;
    // a volume key while one is open would draw the pill over their rows —
    // and there's a visible slider two inches away anyway.
    property bool launcherOpen: false
    property bool clipboardOpen: false

    function show(k: string): void {
        // The countdown is exempt: it's the only feedback that a shutter is
        // about to fire, and suppressing it doesn't stop the screenshot. So is
        // the submap indicator — a rebound keyboard is a state you need to see
        // regardless of what else is on screen.
        if ((root.launcherOpen || root.clipboardOpen) && k !== "countdown" && k !== "submap")
            return;
        root.kind = k;
        // A submap lasts as long as it lasts; every other kind is a value that
        // just changed and is done being interesting after a beat.
        if (k === "submap")
            autoHide.stop();
        else
            autoHide.restart();
    }

    // Explicit dismissal, for callers that need the screen clear at a known
    // moment rather than 1.5s after the last change — a screenshot, mainly.
    function hide(): void {
        autoHide.stop();
        root.kind = "";
    }

    Timer {
        id: autoHide

        interval: 1500
        onTriggered: root.kind = ""
    }

    Timer {
        running: true
        interval: 1500
        onTriggered: root.armed = true
    }

    Connections {
        target: Audio
        enabled: root.armed

        function onVolumeChanged(): void {
            if (!Audio.selfEdit)
                root.show("volume");
        }

        function onMutedChanged(): void {
            if (!Audio.selfEdit)
                root.show("volume");
        }

        function onMicMutedChanged(): void {
            if (!Audio.selfEdit)
                root.show("mic");
        }
    }

    // The keyboard-light Fn key never reaches the compositor on this hardware,
    // so unlike the display keys there's no IPC call to hang this off — asusd
    // handling the key and announcing the result is the whole event.
    Connections {
        target: Brightness
        enabled: root.armed

        function onKbdChangedExternally(): void {
            root.show("kbd");
        }
    }

    // Not filtered on selfEdit, unlike the audio ones: switching the power
    // profile is a rare, deliberate act with no live readout anywhere else on
    // screen, and the confirmation is worth having even when it came from the
    // battery menu two inches away.
    Connections {
        target: Power
        enabled: root.armed

        function onProfileChanged(): void {
            root.show("power");
        }
    }
}
