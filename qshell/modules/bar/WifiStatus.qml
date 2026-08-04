import QtQuick
import qs.config
import qs.components
import qs.services

// Wifi state; click opens the network menu.
//
// When connected the glyph is *drawn* (dot + three arcs, like the battery is
// drawn) so it can grade by signal strength — the F7 icon font has one wifi
// glyph, which made a 95% link and a barely-there one identical. The
// disabled/no-network/ethernet states keep their font glyphs. The whole
// glyph pulses while a connection attempt is in flight — the bar used to
// show nothing at all until the menu was opened.
Item {
    id: root

    property var popouts: null

    readonly property bool drawn: Net.wifiEnabled && Net.connected
    // 1..3 arcs lit. 33/66 splits, so "all arcs" still means a genuinely
    // strong link rather than anything above the old binary 25%.
    readonly property int tier: Net.strength >= 66 ? 3 : Net.strength >= 33 ? 2 : 1

    readonly property string icon: {
        if (!Net.wifiEnabled)
            return "wifi_slash";
        if (Net.ethernet)
            return "globe";
        return "wifi_exclamationmark";
    }

    implicitWidth: (drawn ? arcs.width : glyph.implicitWidth) + Appearance.sizes.modulePad
    implicitHeight: Appearance.sizes.barInner

    StateLayer {
        hitSlop: Appearance.sizes.barSlop
        onClicked: root.popouts?.toggle("wifi", root)
        // macOS menubar: once any bar menu is open, sliding along the bar
        // switches menus without another click.
        onContainsMouseChanged: {
            if (containsMouse && root.popouts?.open && root.popouts.current !== "wifi")
                root.popouts.toggle("wifi", root);
        }
    }

    Item {
        id: glyphBox

        anchors.centerIn: parent
        width: root.drawn ? arcs.width : glyph.implicitWidth
        height: Appearance.sizes.barInner

        SequentialAnimation on opacity {
            running: Net.connecting
            loops: Animation.Infinite
            alwaysRunToEnd: true

            NumberAnimation {
                to: 0.35
                duration: 450
                easing.type: Easing.InOutSine
            }

            NumberAnimation {
                to: 1
                duration: 450
                easing.type: Easing.InOutSine
            }
        }

        FIcon {
            id: glyph

            visible: !root.drawn
            anchors.centerIn: parent
            icon: root.icon
            color: Net.wifiEnabled && Net.ethernet ? Theme.barFg : Theme.barFgDim
        }

        Canvas {
            id: arcs

            // Repaint inputs, mirrored into properties so changes actually
            // trigger onPaint — Canvas doesn't track bindings inside paint().
            readonly property int lit: root.tier
            readonly property color fg: Theme.barFg

            readonly property real lw: Math.max(1.5, Appearance.s(1.9))
            readonly property real dotR: Math.max(1.4, Appearance.s(1.7))
            readonly property real rOuter: Appearance.s(1.7 + 3.6 * 3)

            visible: root.drawn
            anchors.centerIn: parent
            // Derived from the painted shape, not fixed tokens: independently
            // rounded s() values don't compose, and at several scales a fixed
            // box shaved the outer arc's crown and end caps flat.
            width: 2 * Math.ceil(rOuter * Math.SQRT1_2 + lw / 2)
            height: Math.ceil(rOuter + lw / 2 + dotR)

            onLitChanged: requestPaint()
            onFgChanged: requestPaint()
            onVisibleChanged: if (visible) requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                const cx = width / 2;
                // Headroom by construction: apex of the outer stroke lands
                // exactly on y=0, the dot hangs below the arc center.
                const cy = rOuter + lw / 2;
                const dim = Qt.alpha(fg, 0.25);

                // The dot is "connected at all"; each arc is a strength tier.
                ctx.fillStyle = fg;
                ctx.beginPath();
                ctx.arc(cx, cy, dotR, 0, 2 * Math.PI);
                ctx.fill();

                ctx.lineWidth = lw;
                ctx.lineCap = "round";
                for (let i = 1; i <= 3; i++) {
                    ctx.strokeStyle = i <= lit ? fg : dim;
                    ctx.beginPath();
                    // 90° arc opening upward, radii stepping out from the dot.
                    ctx.arc(cx, cy, Appearance.s(1.7 + 3.6 * i), 1.25 * Math.PI, 1.75 * Math.PI);
                    ctx.stroke();
                }
            }
        }
    }
}
