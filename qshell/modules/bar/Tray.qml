import QtQuick
import Quickshell.Services.SystemTray
import qs.config
import qs.components

// Collapsed tray: just an ellipsis until you hover it, then the items slide
// out to the left of the glyph.
//
// Leftward on purpose — the bar's status Row is right-anchored, so growing
// left leaves the ellipsis (and every icon after it) exactly where it was.
// Growing right would shove the trigger out from under the cursor mid-reveal.
Row {
    id: root

    property var popouts: null

    // Don't retract while one of our own menus is open — it's anchored to an
    // item that would otherwise slide away underneath it.
    readonly property bool menuOpen: (popouts?.current ?? "").startsWith("tray:")
    readonly property bool expanded: hover.hovered || menuOpen

    spacing: 0
    visible: SystemTray.items.values.length > 0

    HoverHandler {
        id: hover
    }

    Item {
        id: reveal

        width: root.expanded ? items.implicitWidth : 0
        height: Appearance.sizes.barInner
        clip: true

        Behavior on width {
            Anim {
                duration: Appearance.anim.durations.expressiveFastEffects
                curve: Appearance.anim.curves.standardDecel
            }
        }

        Row {
            id: items

            // Right-aligned inside the clip so items emerge from behind the
            // glyph rather than sliding in from the far left.
            x: reveal.width - implicitWidth
            spacing: 0

            Repeater {
                model: SystemTray.items

                TrayItem {
                    popouts: root.popouts
                }
            }
        }
    }

    Item {
        id: toggle

        implicitWidth: Appearance.sizes.trayCell
        implicitHeight: Appearance.sizes.barInner

        // Full-strength even when collapsed: it's the affordance for a whole
        // hidden row, and a dimmed one reads as a disabled control rather than
        // "there's more over here". The reveal itself is the hover feedback.
        FIcon {
            anchors.centerIn: parent
            icon: "ellipsis"
            color: Theme.barFg
        }
    }
}
