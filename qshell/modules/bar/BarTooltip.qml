import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// The bar's one tooltip surface. Bar modules compute plenty that never fits in
// 26 pixels — battery ETA, SSID and signal, a tray applet's title, the track
// that's playing — and all of it used to be reachable only by opening a menu.
//
// Its own window rather than something drawn in the bar: the bar is
// barHeight tall and a tooltip has to hang *below* it. Input-transparent
// (empty mask), so it can never eat a click meant for the bar or the window
// underneath.
//
// Usage, from a module with `tooltip` pointing here:
//     onContainsMouseChanged: containsMouse ? tooltip.show(text, this) : tooltip.hide(this)
Scope {
    id: root

    required property var barWindow

    // Who asked. Hiding is keyed on it so the module the pointer *left* can't
    // clear a tooltip the module it arrived at has already claimed — with
    // adjacent modules the enter and leave arrive in either order.
    property Item owner: null
    property string text: ""
    property real anchorX: 0

    // Survives `text` clearing, so the pill keeps its label (and its width)
    // through the fade out instead of collapsing to nothing on the way.
    property string held: ""

    onTextChanged: {
        if (text !== "")
            held = text;
    }

    // Nothing is worth reading badly enough to draw it over a menu, a toast or
    // a panel. This surface is created after all of them on the same overlay
    // layer and so wins the stacking order unconditionally — there is no
    // z-order to fix that with, so it stands down instead. And hover-slide
    // means a menu is open exactly when the pointer is running along the
    // modules that raise tooltips, which is precisely when it would overlap.
    readonly property bool shown: text !== "" && owner !== null && !Overlays.any

    function show(text: string, item: Item): void {
        if (!item || !text)
            return;
        root.owner = item;
        root.text = text;
        root.anchorX = item.mapToItem(null, item.width / 2, 0).x;
        // Blocked: record who asked, but don't start counting. Otherwise the
        // delay elapses behind the open menu and the pill springs up the
        // instant the menu closes, unasked.
        if (Overlays.any) {
            delay.stop();
            return;
        }
        // Instant when one is already up (sliding along the bar), delayed on
        // the first — a tooltip that appears the moment the pointer crosses
        // the bar on its way somewhere else is noise.
        if (label.armed)
            delay.stop();
        else
            delay.restart();
    }

    function hide(item: Item): void {
        if (item && root.owner !== item)
            return;
        delay.stop();
        root.owner = null;
        root.text = "";
    }

    Timer {
        id: delay

        interval: 450
        onTriggered: label.armed = true
    }

    // A surface coming up mid-hover cancels the pending reveal outright, so
    // dismissing it doesn't hand back a tooltip nobody asked for. Re-arming
    // takes a fresh hover.
    Connections {
        target: Overlays

        function onAnyChanged(): void {
            if (Overlays.any) {
                delay.stop();
                label.armed = false;
            }
        }
    }

    onShownChanged: {
        if (!shown)
            label.armed = false;
    }

    PanelWindow {
        screen: root.barWindow.screen
        color: "transparent"
        implicitHeight: Appearance.sizes.barHeight + Appearance.s(34)
        // Reserves nothing, but is still *placed* below whatever does — which
        // is the bar, most of the time.
        exclusiveZone: 0

        anchors {
            top: true
            left: true
            right: true
        }

        WlrLayershell.namespace: "qshell:tooltip"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // Never takes input: it exists to be read, and it sits over the top
        // edge of whatever window is below the bar.
        mask: Region {}

        Elevation {
            anchors.fill: label
            radius: label.radius
            level: 2
            visible: label.visible
            opacity: label.opacity
        }

        Rectangle {
            id: label

            // Latched by the delay timer; cleared the moment nothing is
            // claiming the tooltip, so a fast pass-through leaves nothing.
            property bool armed: false

            // 0 hidden, 1 shown — one authority for the fade and the rise.
            property real anim: armed && root.shown ? 1 : 0

            // Clamped to the screen: the tray sits hard against the right edge
            // and its titles are the longest text here.
            x: Math.max(Appearance.s(6), Math.min(root.anchorX - width / 2, parent.width - width - Appearance.s(6)))
            // The compositor already places this window under the bar's
            // exclusive zone — so the offset is measured from the window, and
            // the bar height is only added back in the one case where the bar
            // reserves nothing (hidden over a fullscreen window, revealed by
            // the top-edge strip). Either way the pill lands just under the
            // bar's bottom edge.
            y: (root.barWindow.exclusiveZone > 0 ? 0 : Appearance.sizes.barHeight) + Appearance.s(4) + (1 - anim) * Appearance.s(4)
            implicitWidth: tipText.implicitWidth + Appearance.s(18)
            implicitHeight: Appearance.s(26)
            radius: height / 2
            color: Theme.surfaceBg
            border.width: 1
            border.color: Theme.surfaceBorder

            visible: anim > 0.01
            opacity: anim

            Behavior on anim {
                Anim {
                    duration: Appearance.anim.durations.expressiveFastEffects
                    curve: Appearance.anim.curves.expressiveDefaultEffects
                }
            }

            StyledText {
                id: tipText

                anchors.centerIn: parent
                text: root.held
                color: Theme.surfaceFg
                font.pixelSize: Appearance.font.size.small
            }
        }
    }
}
