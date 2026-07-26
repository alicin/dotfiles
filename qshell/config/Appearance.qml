pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Structure: fonts, sizes, radii, and the animation token set.
// Every size token is multiplied by the global `scale` (settings.json) —
// tweak it live to grow/shrink the whole shell.
// Motion tokens are the Material 3 expressive set as used by
// caelestia-dots/shell (plugin/src/Caelestia/Config/tokens.hpp) — curves are
// cubic bezier splines fed to Easing.BezierSpline.
Singleton {
    id: root

    readonly property real scale: Math.max(0.5, Math.min(2.5, Settings.scale))

    function s(px: real): int {
        return Math.round(px * root.scale);
    }

    readonly property QtObject font: QtObject {
        readonly property string family: "OperatorMono Nerd Font"

        readonly property QtObject size: QtObject {
            readonly property int small: root.s(11)
            readonly property int normal: root.s(13)
            readonly property int large: root.s(15)
        }
    }

    readonly property QtObject sizes: QtObject {
        readonly property int barHeight: root.s(34)
        readonly property int barInner: root.s(26) //  module pill height
        readonly property int icon: root.s(16) //      app/tray icons
        readonly property int wsIcon: root.s(16 * 1.2) // workspace app icons
        readonly property int glyph: root.s(15) //     nerd-font status glyphs
        readonly property int wsDot: root.s(7 * 1.5) // empty workspace circle
        readonly property int slotEmpty: root.s(22) // empty workspace slot width
        readonly property int trayCell: root.s(24)
        readonly property int modulePad: root.s(18) // total h padding of a status pill

        readonly property int launcherWidth: root.s(620)
        readonly property int launcherItemHeight: root.s(56)
        readonly property int launcherRadius: root.s(24)

        readonly property int menuRadius: root.s(18)
        readonly property int menuRowHeight: root.s(40)
    }

    readonly property QtObject rounding: QtObject {
        readonly property int small: root.s(7)
        readonly property int normal: root.s(10)
        readonly property int full: root.s(13) // pill = barInner / 2
    }

    readonly property QtObject anim: QtObject {
        readonly property QtObject durations: QtObject {
            readonly property int small: 200
            readonly property int normal: 400
            readonly property int large: 600
            readonly property int extraLarge: 1000
            readonly property int expressiveFastSpatial: 350
            readonly property int expressiveDefaultSpatial: 500
            readonly property int expressiveSlowSpatial: 650
            readonly property int expressiveFastEffects: 150
            readonly property int expressiveDefaultEffects: 200
            readonly property int expressiveSlowEffects: 300
        }

        readonly property QtObject curves: QtObject {
            readonly property list<real> emphasized: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82, 0.25, 1, 1, 1]
            readonly property list<real> emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
            readonly property list<real> emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
            readonly property list<real> standard: [0.2, 0, 0, 1, 1, 1]
            readonly property list<real> standardAccel: [0.3, 0, 1, 1, 1, 1]
            readonly property list<real> standardDecel: [0, 0, 0, 1, 1, 1]
            readonly property list<real> expressiveFastSpatial: [0.42, 1.67, 0.21, 0.9, 1, 1]
            readonly property list<real> expressiveDefaultSpatial: [0.38, 1.21, 0.22, 1, 1, 1]
            readonly property list<real> expressiveSlowSpatial: [0.39, 1.29, 0.35, 0.98, 1, 1]
            readonly property list<real> expressiveFastEffects: [0.31, 0.94, 0.34, 1, 1, 1]
            readonly property list<real> expressiveDefaultEffects: [0.34, 0.8, 0.34, 1, 1, 1]
            readonly property list<real> expressiveSlowEffects: [0.34, 0.88, 0.34, 1, 1, 1]
        }
    }
}
