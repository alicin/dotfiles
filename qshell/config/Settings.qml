pragma Singleton

import Quickshell
import Quickshell.Io

// Live settings, backed by <shell root>/settings.json. The file is watched, so
// editing it (or `qs -c qshell ipc call theme set <name>`) applies instantly.
Singleton {
    id: root

    readonly property string theme: adapter.theme
    readonly property int workspaces: adapter.workspaces
    readonly property int launcherMaxShown: adapter.launcherMaxShown
    readonly property real scale: adapter.scale
    readonly property int overviewColumns: adapter.overviewColumns
    // Multiplies trackpad scrolling inside the shell's lists only.
    // Clamped so a bad edit can't make lists unscrollable or uncontrollable.
    readonly property real scrollFactor: Math.max(0.25, Math.min(10, adapter.scrollFactor))

    function setTheme(name: string): void {
        adapter.theme = name;
    }

    FileView {
        path: Quickshell.shellPath("settings.json")
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: writeAdapter()

        adapter: JsonAdapter {
            id: adapter

            property string theme: "catppuccin-latte"
            property int workspaces: 12
            property int launcherMaxShown: 8
            property real scale: 1.15
            property int overviewColumns: 6
            property real scrollFactor: 3.5
        }
    }
}
