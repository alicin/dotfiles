import QtQuick
import qs.config
import qs.components

// The Control Center's one container shape: a rounded tint, an optional dim
// caption, then whatever's declared inside stacked vertically. Every group on
// every page uses it, which is what keeps the drill-down pages reading as the
// same panel rather than three dropdowns that happen to share a window.
Rectangle {
    id: root

    property string title: ""
    property real pad: Appearance.s(8)
    property real spacing: Appearance.s(2)

    default property alias content: col.data

    width: parent?.width ?? 0
    implicitHeight: col.y + col.implicitHeight + pad
    radius: Appearance.s(14)
    color: Theme.surfaceHoverBg

    StyledText {
        id: caption

        x: Appearance.s(12)
        y: Appearance.s(7)
        visible: root.title !== ""
        text: root.title
        color: Theme.surfaceFgDim
        font.pixelSize: Appearance.font.size.small
    }

    Column {
        id: col

        // Untitled cards are just padded; titled ones start under the caption.
        y: root.title === "" ? root.pad : caption.y + caption.height + Appearance.s(3)
        width: parent.width
        spacing: root.spacing
    }
}
