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

    // "" | "volume" | "mic" | "brightness" | "kbd" | "power"
    property string kind: ""

    // Bumped on every trigger. The panel watches this rather than the value so
    // a repeat at the end of the range — holding volume-up at 100%, muting
    // twice — still replays the punch, which is the only feedback that the key
    // registered at all.
    property int pulse: 0

    // Pipewire's first notifications are the sink coming up, not a person
    // pressing anything.
    property bool armed: false

    function show(k: string): void {
        root.kind = k;
        root.pulse++;
        hide.restart();
    }

    Timer {
        id: hide

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
