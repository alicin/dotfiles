import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// The floating thumbnail itself. It sizes and positions itself INSIDE the
// screen-sized PipView surface and never touches that surface — see the comment
// there for why the surface must stay a constant.
Item {
    id: root

    // Not `scale`, `state`, `transform`, `rotation`, `children`, `data` or
    // `enabled`: Item already owns every one of those, and a property named
    // after one is a FINAL-override crash rather than a warning. This shell has
    // taken the bar down that way once already (RotateStatus.transform).
    readonly property real cardW: Math.round(Math.max(Appearance.s(200), Math.min(parent.width * 0.6, parent.width * Pip.fraction)))
    readonly property real cardH: Math.round(root.cardW / Pip.aspect)
    readonly property real edge: Appearance.s(16)
    readonly property bool alive: !!Pip.toplevel

    width: root.cardW
    height: root.cardH

    // Out of the picture entirely while a capture is in flight. This surface is
    // on the Overlay layer, so it IS in the screenshot — the same reason the OSD
    // is dismissed before the shutter. `visible`, not a fade: a fade is still
    // half-drawn when grim fires.
    visible: !Capture.hidingUi

    // x/y are deliberately UNBOUND. The drag writes them directly and a binding
    // would fight it; place() re-derives them whenever the geometry that decides
    // where the card belongs changes and no drag is in flight.
    function place(): void {
        if (dragHandler.active)
            return;
        const maxX = Math.max(0, parent.width - root.cardW - root.edge);
        const maxY = Math.max(0, parent.height - root.cardH - root.edge);
        if (Pip.posX >= 0 && Pip.posY >= 0) {
            // Clamped on every replace, not only on drop: the screen can change
            // size under a parked card — rotation, a resolution change, the eDP
            // being toggled — and a card remembered off the new edge is a card
            // you cannot reach to close.
            root.x = Math.max(root.edge, Math.min(maxX, Pip.posX));
            root.y = Math.max(root.edge, Math.min(maxY, Pip.posY));
            return;
        }
        const left = Pip.corner.includes("left");
        const top = Pip.corner.includes("top");
        root.x = left ? root.edge : maxX;
        root.y = top ? root.edge : maxY;
    }

    onCardWChanged: root.place()
    onCardHChanged: root.place()
    Component.onCompleted: root.place()

    Connections {
        target: Pip

        function onCornerChanged(): void {
            root.place();
        }

        function onAddressChanged(): void {
            root.place();
        }
    }

    Connections {
        target: root.parent

        function onWidthChanged(): void {
            root.place();
        }

        function onHeightChanged(): void {
            root.place();
        }
    }

    Elevation {
        anchors.fill: parent
        radius: Appearance.s(12)
        level: 3
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: Appearance.s(12)
        color: Theme.surfaceBg
        border.width: 1
        border.color: hover.hovered ? Theme.accent : Theme.surfaceBorder

        ScreencopyView {
            anchors.fill: parent
            // The toplevel's wayland handle, exactly as the overview does it.
            // Null when the source is gone, which stops the capture rather than
            // leaving the last frame frozen on screen.
            captureSource: root.alive ? (Pip.toplevel.wayland ?? null) : null
            live: true
        }

        // Chrome only on hover — the point of the card is the picture, and a
        // permanent title bar on a 200px thumbnail is most of the thumbnail.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Appearance.s(22)
            color: Qt.alpha(Theme.surfaceBg, 0.92)
            opacity: hover.hovered ? 1 : 0
            visible: opacity > 0.01

            Behavior on opacity {
                Anim {
                    duration: Appearance.anim.durations.expressiveFastEffects
                    curve: Appearance.anim.curves.expressiveFastEffects
                }
            }

            StyledText {
                anchors.left: parent.left
                anchors.leftMargin: Appearance.s(8)
                anchors.right: closeBtn.left
                anchors.rightMargin: Appearance.s(4)
                anchors.verticalCenter: parent.verticalCenter
                text: Pip.title
                color: Theme.surfaceFg
                font.pixelSize: Appearance.font.size.small
                elide: Text.ElideRight
            }

            Item {
                id: closeBtn

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Appearance.s(22)
                height: Appearance.s(22)

                FIcon {
                    anchors.centerIn: parent
                    icon: "xmark"
                    font.pixelSize: Appearance.font.size.small
                    color: closeArea.containsMouse ? Theme.urgent : Theme.surfaceFgDim
                }

                MouseArea {
                    id: closeArea

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Pip.unpin()
                }
            }
        }

        // The source is gone or not drawing. Hyprland re-renders an off-screen
        // window into the export buffer on demand, which is why the overview's
        // thumbnails work at all — but a client that is not being sent frame
        // callbacks stops producing new content, so the capture can be live and
        // the picture still stale. Say so rather than presenting an old frame
        // as news.
        Rectangle {
            anchors.fill: parent
            visible: !root.alive
            color: Qt.alpha(Theme.surfaceBg, 0.85)

            StyledText {
                anchors.centerIn: parent
                text: "source closed"
                color: Theme.surfaceFgDim
                font.pixelSize: Appearance.font.size.small
            }
        }
    }

    HoverHandler {
        id: hover
    }

    // Click the picture to jump to the window it is showing. Not the whole
    // card: the header owns its own clicks so the close button is reachable.
    TapHandler {
        onTapped: {
            if (root.alive)
                Windows.focusAddress(Pip.address);
        }
    }

    DragHandler {
        id: dragHandler

        onActiveChanged: {
            if (!dragHandler.active) {
                // Remember where it was dropped, so a size change or a replace
                // does not send it back to a corner.
                Pip.posX = root.x;
                Pip.posY = root.y;
            }
        }
    }
}
