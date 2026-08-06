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
    //
    // Transient values only. The submap indicator is NOT a kind: it is
    // sustained state with its own property below, and the panel derives what
    // to draw from both. When they shared this one slot, a Pipewire burst and
    // a submap event fought over it — the OSD flickered between the volume
    // pill and the submap legend, and once autoHide fired the legend was gone
    // for good while the submap was still rebinding the keyboard.
    property string kind: ""

    // The Hyprland submap currently active, "" outside one. A submap silently
    // rebinds the whole keyboard — the power one turns `p` into poweroff — and
    // until now the only sign you were in one was that keys did unexpected
    // things.
    property string submap: ""

    // The keys each submap answers to. Hyprland's `submap` event carries only
    // the name, and the bind that enters it carries the description — which
    // lives in the config, not in the event, so it's mirrored here.
    // HAND-MIRRORED from config/hypr/lua/submaps/*.lua: rebinding a submap's
    // keys there silently leaves this legend teaching the old ones — update
    // both, and the entry-bind descriptions in binds.lua, together.
    readonly property var submapHints: ({
            power: "(l)ock  (e)xit  (r)eboot  (p)oweroff  (s)uspend  ·  Esc",
            control: "(s)ound  (b)luetooth  (k)de connect  (d)isplays  (c)ontrol  ·  Esc"
        })

    readonly property string submapLabel: root.submap === "" ? "" : (root.submapHints[root.submap] ?? root.submap)

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name !== "submap")
                return;
            // Leaving a submap sends an empty payload. Nothing else to do:
            // the panel shows the legend whenever `submap` is set and no
            // transient value is on screen.
            root.submap = event.data ?? "";
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

    // A text field inside a bar popout (Wi-Fi password, the Settings page's
    // fields) has focus. Written by Popouts.qml, consumed by services/Osk.qml:
    // popouts are Qt layer surfaces, which never drive zwp_text_input_v3, so
    // without this the on-screen keyboard can't know those fields exist — and
    // a settings field you cannot type into is the panel at its most useless.
    // Lives here with the other panel announcements rather than growing a new
    // singleton for one bit.
    property bool popoutTextFocus: false

    function show(k: string): void {
        // The countdown is exempt: it's the only feedback that a shutter is
        // about to fire, and suppressing it doesn't stop the screenshot.
        if ((root.launcherOpen || root.clipboardOpen) && k !== "countdown")
            return;
        root.kind = k;
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
