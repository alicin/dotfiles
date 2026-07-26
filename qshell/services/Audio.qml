pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink?.ready ?? false
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real volume: sink?.audio?.volume ?? 0

    function setVolume(v: real): void {
        if (root.ready && root.sink.audio)
            root.sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    function toggleMute(): void {
        if (root.ready && root.sink.audio)
            root.sink.audio.muted = !root.sink.audio.muted;
    }

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }
}
