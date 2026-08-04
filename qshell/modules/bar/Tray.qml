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

    // Bumped by items whose status flips in place — `values` alone only
    // re-notifies on add/remove, so a some() over it would sleep through an
    // existing item raising its hand.
    property int attnRev: 0

    // Don't retract while one of our own menus is open — it's anchored to an
    // item that would otherwise slide away underneath it.
    readonly property bool menuOpen: (popouts?.current ?? "").startsWith("tray:")
    // NeedsAttention pierces the collapse: the point of the status is that you
    // see it *without* having hovered first.
    readonly property bool attention: attnRev >= 0 && SystemTray.items.values.some(i => i.status === Status.NeedsAttention)
    readonly property bool expanded: hover.hovered || menuOpen || attention

    spacing: 0
    visible: SystemTray.items.values.length > 0

    HoverHandler {
        id: hover

        margin: Appearance.sizes.barSlop
    }

    Item {
        id: reveal

        width: root.expanded ? items.implicitWidth : 0
        height: Appearance.sizes.barInner

        Behavior on width {
            Anim {
                duration: Appearance.anim.durations.expressiveFastEffects
                curve: Appearance.anim.curves.standardDecel
            }
        }

        // The clip lives on this vertically-extended inner item, not on
        // reveal: reveal is a Row child (positioners own their implicit
        // sizes), and clipping at its 26px bounds swallowed clicks in the
        // bar-edge slop strips that TrayItem's hit areas extend into —
        // making tray icons the only bar controls that ignored edge slams.
        Item {
            y: -Appearance.sizes.barSlop
            width: parent.width
            height: parent.height + 2 * Appearance.sizes.barSlop
            clip: true

            Row {
                id: items

                // Right-aligned inside the clip so items emerge from behind
                // the glyph rather than sliding in from the far left.
                x: parent.width - implicitWidth
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Repeater {
                    model: SystemTray.items

                    TrayItem {
                        popouts: root.popouts
                        tray: root
                    }
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

        // Why the row auto-expanded: some item wants attention.
        Rectangle {
            visible: root.attention
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: Appearance.s(3)
            width: Appearance.s(6)
            height: width
            radius: width / 2
            color: Theme.barWarn
        }
    }
}
