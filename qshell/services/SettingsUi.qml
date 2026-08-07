pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Open/closed state for the standalone Settings window
// (modules/control/SettingsWindow.qml) — a singleton so the Control Center's
// gear row, the IPC surface and the window itself can all reach it without
// the window having to live inside any panel. The window used to be a
// drill-down page in the Control Center popout; it is a real toplevel now
// (macOS System Settings shaped), so "open" means a window exists.
Singleton {
    id: root

    property bool open: false
    // Which sidebar section is showing. Persisted for the session only: like
    // macOS, reopening lands you where you left off, but a fresh login starts
    // at the first section.
    property string section: "appearance"

    function show(section: string): void {
        if (section)
            root.section = section;
        root.open = true;
    }

    IpcHandler {
        target: "settings"

        function open(): string {
            root.show("");
            return "open";
        }

        function close(): string {
            root.open = false;
            return "closed";
        }

        function toggle(): string {
            root.open = !root.open;
            return root.open ? "open" : "closed";
        }

        // `qs -c qshell ipc call settings section tablet`
        function section(name: string): string {
            root.show(name);
            return root.section;
        }
    }
}
