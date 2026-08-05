import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// The macOS post-screenshot thumbnail: what you just captured slides into the
// bottom-right corner, sits there for a few seconds, and slides out.
//
// It earns its keep by being *actionable while it's still the thing you're
// thinking about* — click to open, ⌫ to throw the file away, Annotate to draw
// on it. Hovering holds it open, so reaching for a button never races the
// timer.
//
// The toast for the same file is suppressed while this is up (see
// services/Notifs.qml) — one capture, one announcement — but it still lands in
// the notification history, which is where you go looking an hour later.
Scope {
    id: root

    // The capture being shown; held through the exit animation so the image
    // doesn't blank mid-slide.
    property string path: ""
    property bool open: false

    // Screen this thumbnail is pinned to, by name — see the launcher's pin.
    property string pinned: ""

    onOpenChanged: Overlays.captureThumb = open

    readonly property bool isVideo: /\.(mp4|mkv|webm|mov)$/i.test(root.path)

    Connections {
        target: Capture

        function onCaptured(path: string): void {
            root.path = path;
            // Pinned per showing — the same pin every other transient surface
            // in this shell uses.
            root.pinned = Hyprland.focusedMonitor?.name ?? "";
            root.open = true;
            linger.restart();
        }
    }

    function dismiss(): void {
        root.open = false;
        linger.stop();
    }

    Timer {
        id: linger

        // Long enough to notice and reach for it, short enough that it's gone
        // before it becomes furniture.
        interval: 6000
        running: false
        onTriggered: {
            if (!hover.hovered)
                root.open = false;
            else
                linger.restart();
        }
    }

    PanelWindow {
        id: win

        screen: Quickshell.screens.find(s => s.name === (root.pinned || Hyprland.focusedMonitor?.name)) ?? Quickshell.screens[0] ?? null
        color: "transparent"
        implicitWidth: Appearance.s(300)
        implicitHeight: Appearance.s(230)
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        anchors {
            bottom: true
            right: true
        }

        WlrLayershell.namespace: "qshell:capturethumb"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        mask: Region {
            item: card.visible ? card : null
        }

        Elevation {
            anchors.fill: card
            radius: card.radius
            level: 3
            visible: card.visible
            opacity: card.opacity
        }

        Rectangle {
            id: card

            // 0 hidden, 1 shown — one authority for the slide, the fade and
            // the scale, so they can't drift apart.
            property real anim: root.open ? 1 : 0

            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: Appearance.s(16) - (1 - anim) * Appearance.s(24)
            anchors.bottomMargin: Appearance.s(16)

            width: Appearance.s(230)
            height: Appearance.s(150)
            radius: Appearance.s(14)
            color: Theme.surfaceBg
            border.width: 1
            border.color: Theme.surfaceBorder

            visible: anim > 0.005
            opacity: Math.min(1, anim * 1.4)

            Behavior on anim {
                Anim {
                    duration: root.open ? Appearance.anim.durations.expressiveFastSpatial : Appearance.anim.durations.expressiveDefaultEffects
                    curve: root.open ? Appearance.anim.curves.emphasizedDecel : Appearance.anim.curves.emphasizedAccel
                }
            }

            HoverHandler {
                id: hover
            }

            // The whole card opens the file — that's the verb you want 90% of
            // the time, and the small buttons are the exceptions.
            StateLayer {
                radius: card.radius
                color: Theme.surfaceFg
                onClicked: {
                    Quickshell.execDetached(["xdg-open", root.path]);
                    root.dismiss();
                }
            }

            ClippingRectangle {
                anchors.fill: parent
                anchors.margins: Appearance.s(6)
                radius: Appearance.s(10)
                color: Qt.alpha(Theme.surfaceFg, 0.08)

                Image {
                    id: shot

                    anchors.fill: parent
                    // Images only: a still frame out of an mp4 would need
                    // ffmpeg and a temp file, so recordings get a glyph and
                    // the same actions.
                    source: root.isVideo ? "" : (root.path ? `file://${root.path}` : "")
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    sourceSize.width: Appearance.s(460)
                }

                FIcon {
                    anchors.centerIn: parent
                    visible: shot.status !== Image.Ready
                    icon: root.isVideo ? "film_fill" : "photo_fill"
                    font.pixelSize: Appearance.s(28)
                    color: Theme.surfaceFgDim
                }
            }

            // Dismiss without opening: this is a preview, not a prompt, and it
            // must be possible to make it go away instantly.
            Item {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Appearance.s(2)
                width: Appearance.s(22)
                height: width

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Appearance.s(2)
                    radius: width / 2
                    color: Theme.surfaceBg
                    opacity: 0.85
                }

                StateLayer {
                    radius: width / 2
                    color: Theme.surfaceFg
                    onClicked: root.dismiss()
                }

                FIcon {
                    anchors.centerIn: parent
                    icon: "xmark"
                    font.pixelSize: Appearance.font.size.small
                    color: Theme.surfaceFgDim
                }
            }

            // Annotate, on hover only: it's the third-most-likely thing to
            // want, and a permanent button on a 150px card competes with the
            // image it's about.
            Rectangle {
                visible: hover.hovered && !root.isVideo
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Appearance.s(12)
                implicitWidth: editRow.implicitWidth + Appearance.s(18)
                implicitHeight: Appearance.s(26)
                radius: height / 2
                color: Theme.surfaceBg
                border.width: 1
                border.color: Theme.surfaceBorder

                StateLayer {
                    radius: parent.radius
                    color: Theme.surfaceFg
                    onClicked: {
                        Capture.annotate(root.path);
                        root.dismiss();
                    }
                }

                Row {
                    id: editRow

                    anchors.centerIn: parent
                    spacing: Appearance.s(5)

                    FIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "pencil_outline"
                        font.pixelSize: Appearance.font.size.small
                        color: Theme.surfaceFg
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Annotate"
                        color: Theme.surfaceFg
                        font.pixelSize: Appearance.font.size.small
                    }
                }
            }
        }
    }
}
