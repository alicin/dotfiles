import QtQuick
import qs.config

// Base animation: M3 standard curve @ 400ms. Override `curve`/`duration` at
// the use site, e.g. Anim { curve: Appearance.anim.curves.emphasized }.
NumberAnimation {
    property list<real> curve: Appearance.anim.curves.standard

    duration: Appearance.anim.durations.normal
    easing.type: Easing.BezierSpline
    easing.bezierCurve: curve
}
