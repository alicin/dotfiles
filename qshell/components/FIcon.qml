import QtQuick
import qs.config

// Framework7 Icons (MIT), straight from the upstream font — no patching.
// The font is ligature-driven: set the text to the icon's name and the `liga`
// feature substitutes the glyph, longest match first (so "wifi_slash" wins
// over "wifi"). That's why there's no codepoint map to maintain.
//
// A name the font doesn't know renders as literal letters rather than tofu,
// which is a louder and more useful failure than an invisible glyph.
//
// Usage: FIcon { icon: "wifi" }
Text {
    property string icon: ""

    text: icon
    font.family: "Framework7 Icons"
    font.pixelSize: Appearance.s(17)
    color: Theme.barFg
    verticalAlignment: Text.AlignVCenter

    Behavior on color {
        CAnim {}
    }
}
