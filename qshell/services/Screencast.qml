pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// "Is my screen going somewhere right now" — the third privacy light, next to
// the mic and the camera.
//
// A portal screencast is a PipeWire node the *portal* publishes and the asking
// app consumes, so the shape is Audio.qml's micUsers: find the node, then read
// the live link groups off the global list to name whoever is on the other end.
// PwNodeLinkTracker is no good here for the same reason it wasn't there — it
// wants both ends bound before it reports anything, and stays empty otherwise.
//
// The hard part is telling that node from a webcam, and the obvious guess is
// wrong. Both portal backends installed here publish the cast with media.class
// "Video/Source" — the *same* class the v4l2 webcams carry — so the class
// discriminates nothing. Read out of the shipped binaries and confirmed against
// upstream source: xdg-desktop-portal-hyprland 1.4.1 does
// pw_stream_new(name = "xdph-streaming-<rand>", media.class = "Video/Source"),
// and xdg-desktop-portal-wlr 0.8.2 the same with "xdpw-stream-<rand>".
//
// That name lands in *media.name*, not node.name: pw_stream_new only falls back
// to the stream name for node.name when the client has no application.name of
// its own, and both portals do have one — so node.name is most likely the
// literal string "xdg-desktop-portal-hyprland" and media.name is where the
// giveaway prefix lives. Both keys are checked, because "most likely" is not a
// thing to hang a privacy light on.
//
// What actually separates a cast from a camera is the v4l2 tail the cameras
// drag behind them — device.api, media.role=Camera, api.v4l2.path, an object
// path of v4l2:/dev/videoN. A portal cast is a client stream and has none of
// it. That exclusion is the load-bearing half: Camera.qml already lights up for
// every v4l2 open (it counts uvcvideo handles), and two lights for one fact is
// worse than no light at all.
//
// ── What was verified, and what wasn't ──
//
// The portal node names and media.class come from the shipped binaries in
// /usr/lib and their upstream sources at the exact versions installed here —
// read, not guessed, but read rather than observed.
//
// Everything else was exercised against a *synthetic* cast: gst-launch's
// pipewiresink in provide mode, publishing Video/Source with media.name forged
// to each portal prefix in turn. Not a screencast, but a real client-owned
// video stream in the real graph, which is the shape this file keys off. That
// run established: the cameras stay excluded and the fake is picked up; the
// light goes up when the node appears and down when it dies, both directions,
// live; a consumer attached with pipewiresrc is found through the link groups
// and named; and an unrecognised name still trips the fallback tier. It also
// caught the Stream/Input/Video bug noted below, which reading alone hadn't.
//
// NOT verified: an actual portal screencast has never been run against this
// code. That a real cast produces the node at all, on Start rather than on the
// consumer's first frame, is inference. dump() exists for exactly that reason:
// start a cast, run `qs -c qshell ipc call debug screencast`, and the real
// graph is on the screen instead of in this comment.
Singleton {
    id: root

    // Presence of the node is the signal, not link state. The portal creates
    // this node on Start and destroys it when the session ends, so it exists
    // for the whole cast — whereas the consumer's link may lag it by a beat at
    // the start, and PipeWire reports link groups as Unlinked mid-stream anyway
    // (measured on the mic, see Audio.qml, and again here: a link pw-dump calls
    // active comes through as state -1). Erring toward "on" is the right
    // direction for the same reason Camera.qml counts opens rather than frames.
    readonly property bool active: casts.length > 0

    // Who is receiving the cast. Empty while the node exists but nothing has
    // linked to it yet — the light is already up by then, deliberately.
    readonly property list<string> apps: {
        const out = [];
        for (const node of root.casts) {
            for (const g of Pipewire.linkGroups.values) {
                // The cast is the producing end, but check both: a portal that
                // wired itself the other way round would otherwise go unnamed
                // rather than merely unlabelled.
                if (g.source !== node && g.target !== node)
                    continue;
                const peer = g.target === node ? g.source : g.target;
                if (!peer || root.casts.includes(peer))
                    continue;
                // application.name first to match how micUsers names things,
                // but node.name is what usually answers: PipeWire 1.6.8 here
                // does not copy application.name onto stream nodes, and
                // pw_stream already seeds node.name from the client's
                // application name, so the fallback carries the real weight.
                const name = (peer.properties?.["application.name"] ?? "") || peer.description || peer.name;
                if (name && !out.includes(name))
                    out.push(name);
            }
        }
        return out;
    }

    // The portal-published video nodes, if any.
    readonly property var casts: [...Pipewire.nodes.values].filter(n => root.isCast(n.properties ?? ({})))

    // A node that produces video and is not one of the cameras.
    //
    // Two tiers, and the second one is on purpose. Tier one is the known portal
    // name prefixes, which is certainty. Tier two is any video producer that
    // isn't backed by a device at all — a client stream, which is what every
    // portal cast is and what no webcam is. A portal this file has never heard
    // of is precisely the case where a missing light costs something, and the
    // cost of a spurious one is a moment of "what's that?", so the catch-all
    // stays. The known false positive is an app publishing video into PipeWire
    // for a reason of its own; nothing on this machine does, verified by the
    // idle graph having exactly two video nodes, both cameras.
    function isCast(p: var): bool {
        if (!root.isVideoProducer(p) || root.isCameraNode(p))
            return false;
        const named = /^(xdph-streaming-|xdpw-stream-)/;
        if (named.test(p["media.name"] ?? "") || named.test(p["node.name"] ?? ""))
            return true;
        return p["device.id"] === undefined && p["device.api"] === undefined;
    }

    // "Video/Source" is what both portals here use; "Stream/Output/Video" is
    // what the GNOME and GTK portals use, and both of those are installed, so
    // they're worth the extra clause even though Hyprland's backend wins the
    // portal lookup on this machine.
    //
    // Spelled out rather than matched as Stream/*/Video, which is how this was
    // first written and which lit up the *consumer* as a second cast:
    // Stream/Input/Video is the app receiving the screen, and it sits on the
    // far end of the very link used to name it — so it named itself, and `apps`
    // came back empty. Caught with a synthetic node, see the header.
    function isVideoProducer(p: var): bool {
        const c = p["media.class"] ?? "";
        return c === "Video/Source" || c === "Stream/Output/Video";
    }

    // Any one of these is enough — a v4l2 node is Camera.qml's to light up.
    // Four checks rather than one because they come from different layers
    // (session manager, spa plugin, PipeWire core) and a node missing one of
    // them for a reason nobody here has seen must not fall through into a
    // second light for a camera that's already lit.
    function isCameraNode(p: var): bool {
        return (p["device.api"] ?? "") === "v4l2" || (p["media.role"] ?? "") === "Camera" || p["api.v4l2.path"] !== undefined || (p["node.name"] ?? "").startsWith("v4l2_");
    }

    // `qs -c qshell ipc call debug screencast` — the whole point of which is
    // that the predicate above was written blind. Prints every node with a
    // video smell, whether or not it matched, and says why it didn't.
    function dump(): string {
        const rows = [];
        for (const n of Pipewire.nodes.values) {
            const p = n.properties ?? ({});
            // Untracked nodes report empty properties, so the type flag is the
            // only thing left to notice a video node by — worth listing, since
            // "nothing showed up" and "it showed up unbound" are very different
            // bugs and this is the only place they can be told apart.
            const flagged = (n.type & PwNodeType.Video) !== 0;
            if (!root.isVideoProducer(p) && !flagged && (p["media.class"] ?? "").indexOf("Video") === -1)
                continue;
            const why = root.isCast(p) ? "CAST" : root.isCameraNode(p) ? "skip: v4l2 camera — Camera.qml owns it" : !root.isVideoProducer(p) ? "skip: not a video producer" : "skip: device-backed, unrecognised name";
            rows.push(`  #${n.id} ${n.name || "?"} [${p["media.class"] ?? "-"}] ${why}\n` + `      media.name=${p["media.name"] ?? "-"} app=${p["application.name"] ?? "-"} device.api=${p["device.api"] ?? "-"} role=${p["media.role"] ?? "-"} ready=${n.ready} props=${Object.keys(p).length}`);
            for (const g of Pipewire.linkGroups.values) {
                if (g.source !== n && g.target !== n)
                    continue;
                const peer = g.target === n ? g.source : g.target;
                rows.push(`      ↔ #${peer?.id ?? "?"} ${peer?.properties?.["application.name"] ?? peer?.name ?? "?"} (state ${g.state})`);
            }
        }
        if (rows.length === 0)
            rows.push("  (no video nodes at all)");
        return `active=${root.active} casts=${root.casts.length} apps=${JSON.stringify(root.apps)}\n${rows.join("\n")}`;
    }

    // Every node, not just the video ones: `properties` is empty until a node
    // is bound, and the node that needs identifying is one that doesn't exist
    // yet — so there is nothing narrower to track. Audio.qml holds an identical
    // tracker; they're refcounted, and this service standing on its own is
    // worth more than the duplicate costs.
    PwObjectTracker {
        objects: [...Pipewire.nodes.values]
    }
}
