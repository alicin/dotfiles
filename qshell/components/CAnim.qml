import QtQuick
import qs.config

// Color transition — caelestia's CAnim (expressive slow effects).
ColorAnimation {
    duration: Appearance.anim.durations.expressiveSlowEffects
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Appearance.anim.curves.expressiveSlowEffects
}
