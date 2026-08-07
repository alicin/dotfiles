pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// The pinned Picture-in-Picture source. State only — modules/pip draws it.
//
// A singleton rather than state inside the module because services/Search.qml
// needs to reach it to offer "Pin as Picture-in-Picture" on a window row, and
// Search cannot import qs.modules. Search's own comment already rejects the
// alternative of shelling out to `qs ipc call` to talk to ourselves.
Singleton {
    id: root

    // The BARE address, in Windows.key form — never the toplevel object.
    // Quickshell destroys a HyprlandToplevel outright on `closewindow`, and
    // every held reference silently becomes null; Windows.focusAddress and
    // Search's window rows are both written around exactly this. Holding the
    // object here would turn "the window you were watching closed" into a
    // frozen picture that never updates and never goes away.
    property string address: ""

    // Session placement. Deliberately NOT persisted: an address means nothing
    // across a Hyprland restart, and re-pinning is one keypress.
    property string corner: "bottomright"

    // -1/-1 means "unplaced, snap to `corner`". Written by the card's drag.
    property real posX: -1
    property real posY: -1

    // Fraction of the screen width the card occupies. Session state, like the
    // corner: a size you chose for one window is rarely the size you want for
    // the next one.
    property real fraction: 0.24

    readonly property bool active: root.address !== ""

    // Re-resolved on every read, never cached, for the same reason the address
    // is a string. Windows.rev is in the binding because a list built from
    // toplevels is not re-evaluated when a member changes — Windows already
    // bumps rev on open/close/move/title churn.
    readonly property var toplevel: {
        Windows.rev;
        if (!root.address)
            return null;
        return Hyprland.toplevels.values.find(t => Windows.keyOf(t) === root.address) ?? null;
    }

    readonly property string title: {
        const t = root.toplevel;
        if (!t)
            return "";
        return t.title || t.lastIpcObject?.title || t.lastIpcObject?.class || t.wayland?.appId || "Untitled";
    }

    // The source's own aspect, taken from Hyprland's geometry rather than from
    // the capture: ScreencopyView's frame size is not known until the first
    // frame lands, and a 0-height source divides into NaN, which is the class
    // of bug that printed a warning per overview cell forever.
    readonly property real aspect: {
        Windows.rev;
        const s = root.toplevel?.lastIpcObject?.size ?? null;
        return (s && s[0] > 0 && s[1] > 0) ? s[0] / s[1] : 16 / 9;
    }

    function isPinned(addr: string): bool {
        return root.address !== "" && root.address === Windows.key(addr);
    }

    // Empty address means the focused window, which is the keybind case: you
    // are looking at the thing, you press the key, you switch away.
    function pin(addr: string): bool {
        const k = Windows.key(addr || Windows.keyOf(Hyprland.activeToplevel));
        if (!k)
            return false;
        root.address = k;
        root.posX = -1;
        root.posY = -1;
        return true;
    }

    function unpin(): void {
        root.address = "";
        root.posX = -1;
        root.posY = -1;
    }

    function toggle(addr: string): bool {
        const k = Windows.key(addr || Windows.keyOf(Hyprland.activeToplevel));
        if (root.isPinned(k)) {
            root.unpin();
            return false;
        }
        return root.pin(k);
    }

    // The source going away unpins, rather than leaving a card showing the last
    // frame of a window that no longer exists. Hyprland's closewindow is what
    // Windows.rev is already bumped by, so this rides the existing signal
    // instead of adding another Connections on the same event.
    onToplevelChanged: {
        if (root.address !== "" && !root.toplevel)
            root.unpin();
    }
}
