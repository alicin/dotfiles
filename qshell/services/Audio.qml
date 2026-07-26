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

    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool micMuted: source?.audio?.muted ?? false
    readonly property real micVolume: source?.audio?.volume ?? 0

    // True for a beat after the shell writes one of these itself. The OSD keys
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

    function setMicVolume(v: real): void {
        if (root.source?.audio) {
            root.markSelfEdit();
            root.source.audio.volume = Math.max(0, Math.min(1, v));
        }
    }

    function toggleMicMute(): void {
        if (root.source?.audio) {
            root.markSelfEdit();
            root.source.audio.muted = !root.source.audio.muted;
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

    // The source is tracked too, not just the sink: `audio` only populates for
    // tracked nodes, and the bar's mic indicator has to know whether the mic is
    // muted without the Sound page being open to do the tracking for it.
    PwObjectTracker {
        objects: [root.sink, root.source].filter(n => n)
    }
}
