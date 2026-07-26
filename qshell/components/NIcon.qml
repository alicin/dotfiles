import QtQuick
import qs.config

// Nerd-font glyph, for the handful of icons Framework7 genuinely doesn't ship
// (bluetooth, mouse, watch — the set has no bluetooth glyph at all).
//
// The Nerd Font's Material glyphs sit small in their em box, so a matched
// pixelSize reads punier than the F7 icons beside them; this compensates, at
// 10% below the size that optically matched.
// Usage: NIcon { text: "󰂯" }
Text {
    font.family: Appearance.font.family
    font.pixelSize: Math.round(Appearance.s(17) * 1.06)
    color: Theme.barFg
    verticalAlignment: Text.AlignVCenter

    Behavior on color {
        CAnim {}
    }
}
