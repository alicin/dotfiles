pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink?.ready ?? false
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real volume: sink?.audio?.volume ?? 0

    // True for a beat after the shell writes the volume itself. The OSD keys
    // off Pipewire's change signal — which fires for *any* writer, so a media
    // key, pavucontrol and a headset button all work with no plumbing — and
    // this is how it tells those from a Control Center slider drag, which
    // already has a visible control under the cursor.
    property bool selfEdit: false

    function setVolume(v: real): void {
        if (root.ready && root.sink.audio) {
            root.markSelfEdit();
            root.sink.audio.volume = Math.max(0, Math.min(1, v));
        }
    }

    function toggleMute(): void {
        if (root.ready && root.sink.audio) {
            root.markSelfEdit();
            root.sink.audio.muted = !root.sink.audio.muted;
        }
    }

    function markSelfEdit(): void {
        root.selfEdit = true;
        selfEditWindow.restart();
    }

    // Long enough to cover the round trip out to Pipewire and back, short
    // enough that letting go of a slider and hitting a key still shows an OSD.
    Timer {
        id: selfEditWindow

        interval: 350
        onTriggered: root.selfEdit = false
    }

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }
}
