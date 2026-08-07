import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.services

// The on-screen keyboard surface. State, layouts and key injection live in
// services/Osk.qml; this is the glass.
//
// The single most important line in here is `exclusiveZone`. A layer surface
// that claims one makes the compositor shrink the *tiled* layout by exactly
// that much, so every tiled window gets out of the keyboard's way for free and
// stays out of it — no polling, no per-window arithmetic, and it survives new
// windows opening while the keyboard is up. Floating windows get no such
// treatment from Hyprland, which is what bin/osk-float-rescue is for; the
// service drives it off the same two numbers this file publishes.
Scope {
    id: root

    // Pinned by name at show time, like the launcher: with focus-follows-mouse
    // a live binding to the focused monitor would teleport the keyboard to
    // another screen the moment the pointer crossed, mid-word. A name outlives
    // the ShellScreen object, which does not survive an unplug or a reload.
    property string pinned: ""

    readonly property int panelHeight: Math.round((win.screen?.height ?? 1080) * Settings.oskHeight)

    Connections {
        target: Osk

        function onActiveChanged(): void {
            if (Osk.active) {
                root.pinned = Hyprland.focusedMonitor?.name ?? "";
                // Always come back on the letters layer with nothing latched.
                // Reopening into a half-built Ctrl+Shift from ten minutes ago
                // is a keyboard that types garbage for one keystroke and gives
                // no hint why.
                Osk.layer = 0;
                Osk.shiftLock = false;
                Osk.ctrlLock = false;
                Osk.altLock = false;
                Osk.logoLock = false;
                Osk.clearOneShots();
            }
        }
    }

    // The two numbers services/Osk.qml hands to the float rescue. Published
    // from here because the panel is what actually knows its screen and its
    // height, and a second copy of either is a second thing that can be wrong.
    Binding {
        target: Osk
        property: "reservedPx"
        value: Osk.active ? root.panelHeight : 0
    }

    Binding {
        target: Osk
        property: "reservedScreen"
        value: win.screen?.name ?? ""
    }

    // For the launcher/clipboard/popout focus grabs: a grab that doesn't
    // whitelist this window closes its panel on the first key tap.
    Binding {
        target: Osk
        property: "panelWindow"
        value: win
    }

    PanelWindow {
        id: win

        screen: Quickshell.screens.find(s => s.name === (root.pinned || Hyprland.focusedMonitor?.name)) ?? Quickshell.screens[0] ?? null
        visible: Osk.active
        color: "transparent"
        implicitHeight: root.panelHeight

        anchors {
            left: true
            right: true
            bottom: true
        }

        // The whole point — see the file header.
        exclusiveZone: root.panelHeight

        WlrLayershell.namespace: "qshell:osk"
        // Overlay rather than Top so it draws above the launcher and the
        // clipboard picker, which are the two panels you would most want to
        // type into. Both are told to keep their distance (they anchor to the
        // bottom too, and take a margin from Osk.reservedPx).
        WlrLayershell.layer: WlrLayer.Overlay
        // Never. A layer surface that takes keyboard focus takes it *away from
        // the app you are typing into*, and every keystroke would land in the
        // keyboard itself.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            id: backdrop

            anchors.fill: parent
            // The theme's surface colour, forced opaque. Every other panel in
            // this shell keeps its 97% alpha and looks better for it, but they
            // are all transient: you glance at a launcher, you read a menu. The
            // keyboard is up for as long as you are typing, it is a dense grid
            // of low-contrast caps, and 3% of a browser page bleeding through
            // puts ghost text *inside* the keys — measurably, in a screenshot
            // of this panel over a cookie banner.
            color: Qt.alpha(Theme.surfaceBg, 1)
            // Only the top corners: the other two are against the screen edge.
            topLeftRadius: Appearance.sizes.menuRadius
            topRightRadius: Appearance.sizes.menuRadius

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: Theme.surfaceBorder
            }

            Column {
                id: rows

                anchors.fill: parent
                anchors.margins: Appearance.sizes.oskPad
                spacing: Appearance.sizes.oskGap

                // Six rows, five gaps. The utility row is deliberately shorter
                // than a typing row: it holds the keys you reach for once a
                // sentence (Escape, the arrows) rather than once a word, and
                // every pixel it gives back goes to the letters.
                readonly property real utilityWeight: 0.8
                readonly property real unit: Math.max(0, (height - spacing * Osk.rows.length) / (Osk.rows.length + utilityWeight))

                OskRow {
                    keys: Osk.rowUtility
                    width: rows.width
                    height: rows.unit * rows.utilityWeight
                }

                Repeater {
                    model: Osk.rows

                    OskRow {
                        required property var modelData

                        keys: modelData
                        width: rows.width
                        height: rows.unit
                    }
                }
            }
        }
    }
}
