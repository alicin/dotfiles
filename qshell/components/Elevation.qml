import QtQuick
import QtQuick.Effects
import qs.config

// Drop shadow for floating surfaces (menus, launcher, toasts) — caelestia's
// Elevation: an M3 dp table driving RectangularShadow. Place it behind the
// surface with anchors.fill + matching radius.
RectangularShadow {
    property int level: 3

    readonly property real dp: [0, 1, 3, 6, 8, 12][level]

    color: Theme.shadow
    blur: (dp * 5) ** 0.7
    spread: -dp * 0.3 + (dp * 0.1) ** 2
    offset.y: dp / 2
}
