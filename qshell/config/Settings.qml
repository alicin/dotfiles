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
        }
    }
}
