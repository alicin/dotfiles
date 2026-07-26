import QtQuick
import qs.config

Text {
    color: Theme.barFg
    font.family: Appearance.font.family
    font.pixelSize: Appearance.font.size.normal
    font.weight: Font.Medium
    verticalAlignment: Text.AlignVCenter

    Behavior on color {
        CAnim {}
    }
}
