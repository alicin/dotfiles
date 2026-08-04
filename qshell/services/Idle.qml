pragma Singleton

import Quickshell

// Sleep prevention. Holds only the flag — the actual wayland idle-inhibit
// surface lives on the bar window (modules/bar/Bar.qml), because the inhibitor
// needs a mapped window and the Control Center that toggles it is destroyed
// every time the menu closes.
//
// Inhibiting at the compositor means hypridle never sees the idle event, so
// its dim / lock / suspend listeners all stay parked — no need to stop the
// daemon or hold a systemd lock it wouldn't honour anyway.
Singleton {
    id: root

    // Persisted like its sibling toggles (DND, the record-audio prefs): a
    // config reload — constant while hacking on this shell — used to silently
    // drop Keep Awake, and the machine then dimmed or suspended mid-download
    // with no warning.
    readonly property bool inhibited: persist.inhibited

    function toggle(): void {
        persist.inhibited = !persist.inhibited;
    }

    PersistentProperties {
        id: persist

        reloadableId: "qshellIdle"

        property bool inhibited: false
    }
}
