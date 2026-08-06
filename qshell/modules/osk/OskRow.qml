import QtQuick
import qs.config
import qs.services

// One row of keys, normalised to the panel width.
//
// Widths are weights, not pixels: the row divides whatever it is given between
// its keys in proportion. That is what lets the home row (nine letters plus a
// 1.75-wide Return) and the row above it (ten letters) both fill the panel
// edge to edge, with the home row's keys coming out slightly wider — which is
// how a real keyboard looks, and the alternative is either a ragged right edge
// or a hardcoded pixel table that breaks on every screen but this one.
Item {
    id: root

    required property var keys

    readonly property real gap: Appearance.sizes.oskGap
    readonly property real weight: root.keys.reduce((sum, k) => sum + (Osk.spec(k).w ?? 1), 0)
    readonly property real unit: Math.max(0, (root.width - root.gap * (root.keys.length - 1)) / root.weight)

    Row {
        anchors.fill: parent
        spacing: root.gap

        Repeater {
            model: root.keys

            OskKey {
                required property var modelData

                key: modelData
                width: root.unit * (Osk.spec(modelData).w ?? 1)
                height: root.height
            }
        }
    }
}
