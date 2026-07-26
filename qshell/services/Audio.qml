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

    // Live links on the mic node — i.e. something is actually *capturing*, as
    // opposed to the mic merely being unmuted. An idle unmuted mic is not a
    // privacy event, and an indicator lit all day is one you stop seeing, so
    // this is what the bar's warning keys off rather than `micMuted`.
    //
    // Existence of the group is the whole signal; its `state` deliberately
    // isn't consulted. PipeWire reports these as Unlinked (-1) here even
    // mid-recording, tracked or not, so filtering on Active never matches —
    // whereas the group itself appears and disappears exactly with the client
    // (measured: 0 idle, 1 through a capture, 0 after).
    //
    // Read off the global list rather than a PwNodeLinkTracker, which needs
    // both ends bound before it reports anything and so stayed empty.
    readonly property var micLinkGroups: {
        const src = root.source;
        if (!src)
            return [];
        return [...Pipewire.linkGroups.values].filter(g => g.source === src || g.target === src);
    }

    readonly property bool micInUse: micLinkGroups.length > 0

    // What's listening, so "who?" has an answer that isn't a process list.
    // Whichever end of the link isn't the mic is the consumer.
    readonly property var micUsers: {
        const out = [];
        for (const g of root.micLinkGroups) {
            const n = g.target === root.source ? g.source : g.target;
            if (!n)
                continue;
            const name = (n.properties?.["application.name"] ?? "") || n.description || n.name;
            if (name && !out.includes(name))
                out.push(name);
        }
        return out;
    }

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

    // Everything, not just the default sink and source: `properties`
    // (application.name) populates only for tracked nodes, and the node that
    // needs naming is whatever stream turns up mid-recording — not something
    // that can be known in advance.
    PwObjectTracker {
        objects: [...Pipewire.nodes.values]
    }
}
