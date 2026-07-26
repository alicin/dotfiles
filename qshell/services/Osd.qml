pragma Singleton

import QtQuick
import Quickshell

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
    property string kind: ""

    // Pipewire's first notifications are the sink coming up, not a person
    // pressing anything.
    property bool armed: false

    function show(k: string): void {
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
