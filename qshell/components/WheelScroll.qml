import QtQuick
import qs.config

// Drop inside a Flickable/ListView to make trackpad scrolling keep up.
//
// Hyprland sets `input:touchpad:scroll_factor = 0.3` globally, and Qt's
// Flickable takes that already-scaled delta at face value — native apps layer
// their own acceleration on top, which is why only the shell felt sluggish.
// Boosting here rather than raising the global factor leaves every other app
// alone. (Measured: ~2-6px per event at 8ms intervals before the factor.)
//
// Deliberately no momentum: the list tracks the fingers 1:1 and stops when
// they do.
//
// Usage:  WheelScroll { view: myListView }
WheelHandler {
    id: root

    // The Flickable to drive. Defaults to whatever this is declared inside,
    // which is the common case.
    property var view: parent

    property real factor: Settings.scrollFactor

    // A horizontal ListView scrolls along contentX and never grows contentHeight
    // past its own height, so driving contentY on one is a no-op — and since
    // this handler consumes the event either way, the view ends up completely
    // unscrollable. Read off the view when it says, so a caller doesn't have
    // to know.
    readonly property bool horizontal: root.view?.orientation === ListView.Horizontal

    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

    onWheel: event => {
        if (!view || view.contentHeight === undefined)
            return;

        // A wheel mouse only ever reports on the Y axis, and a trackpad's
        // horizontal gesture reports on X — a horizontal list takes whichever
        // arrived, or neither works depending on the device.
        const px = root.horizontal ? (event.pixelDelta.x || event.pixelDelta.y) : event.pixelDelta.y;
        const ang = root.horizontal ? (event.angleDelta.x || event.angleDelta.y) : event.angleDelta.y;

        // Fingers lifting produces a zero-delta event (wayland's axis_stop).
        // Nothing to scroll, but it still has to be consumed.
        if (px === 0 && ang === 0) {
            event.accepted = true;
            return;
        }

        // Touchpads send high-resolution pixelDelta, mice send angleDelta in
        // eighths of a degree (a notch being 120). The factor is touchpad-only:
        // hyprland's scroll_factor lives under `touchpad`, so the wheel was
        // never slowed and doesn't need speeding up.
        const raw = px !== 0 ? px * root.factor : (ang / 120) * Appearance.s(60);

        // Same sign convention as Flickable itself: content moves opposite the
        // scroll direction, so natural_scroll stays consistent with every other
        // list on the system.
        if (root.horizontal) {
            const maxX = Math.max(0, view.contentWidth - view.width);
            view.contentX = Math.max(0, Math.min(maxX, view.contentX - raw));
        } else {
            const max = Math.max(0, view.contentHeight - view.height);
            view.contentY = Math.max(0, Math.min(max, view.contentY - raw));
        }

        // Consume it, or Flickable applies its own unscaled scroll on top and
        // the list jumps by 1 + factor.
        event.accepted = true;
    }
}
