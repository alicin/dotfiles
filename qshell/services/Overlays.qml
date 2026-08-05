pragma Singleton

import Quickshell

// Which of the shell's own surfaces are currently on screen.
//
// One consumer today — the bar tooltip, which must never draw over a menu,
// a toast or a panel. It sits on the same overlay layer as all of them and,
// being created last, wins the stacking order every time; there is no z-order
// to fix this with, so the tooltip has to stand down instead.
//
// Mostly derived rather than written: `menuOpen` and the popup list already
// exist and are already maintained, and a second copy of a fact is a second
// thing that can be wrong. Only the two surfaces with no existing global flag
// report in.
Singleton {
    id: root

    // Written by Overview and CaptureThumb, which have no other global state.
    property bool overview: false
    property bool captureThumb: false

    // Bar popouts (menus + Control Center). With several bars the last writer
    // wins, which is right here: the pointer is only ever on one of them.
    readonly property bool menus: Notifs.menuOpen

    // The launcher and clipboard picker already announce themselves so the OSD
    // can get out of their way.
    readonly property bool panels: Osd.launcherOpen || Osd.clipboardOpen

    readonly property bool toasts: Notifs.popups.length > 0 && !Notifs.popupsHidden

    readonly property bool any: root.menus || root.panels || root.toasts || root.overview || root.captureThumb
}
