pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Pushes the shell's theme out to everything else with colors — kitty, GTK,
// Chrome (via the portal), VS Code — by running scripts/theme-sync.sh on
// every change. The mapping tables live in the script, not here: the QML
// side's whole job is to notice.
//
// Fires on *change*, not at startup: the world was already synced to the
// current theme when the shell last ran, and re-writing four programs'
// configs on every login (or shell reload, which recreates this singleton)
// would be churn with no observable effect.
//
// Referenced from shell.qml so the singleton actually instantiates — nothing
// else imports it, and a singleton nobody references is never created.
Singleton {
    id: root

    readonly property string script: `${Quickshell.env("HOME")}/labs/dotfiles/scripts/theme-sync.sh`

    // Set once the initial value has been seen; everything after is a real
    // change made by a person.
    property string current: ""

    Connections {
        target: Settings

        function onThemeChanged(): void {
            // Nothing counts until settings.json has actually loaded: before
            // that, `theme` is the JsonAdapter DEFAULT, and seeding from it
            // made the async default→saved flip look like a real change — so
            // the script ran on every login and every live-reload (kitty
            // SIGUSR1 hitch, portal writes, a VS Code settings.json rewrite),
            // defeating the guard this file's header describes.
            if (!Settings.ready || root.current === Settings.theme)
                return;
            const first = root.current === "";
            root.current = Settings.theme;
            if (!first)
                Quickshell.execDetached([root.script, Settings.theme]);
        }

        function onReadyChanged(): void {
            // Cold start: the file loads after this singleton exists.
            if (Settings.ready && root.current === "")
                root.current = Settings.theme;
        }
    }

    // Live-reload: the singleton is recreated while Settings is already
    // ready, so onReadyChanged never fires — seed here instead.
    Component.onCompleted: {
        if (Settings.ready)
            root.current = Settings.theme;
    }
}
