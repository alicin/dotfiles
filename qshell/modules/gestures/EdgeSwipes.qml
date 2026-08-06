import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Three invisible strips down the edges of the screen, each listening for one
// swipe. What they do about it is in services/Gestures.qml.
//
//   bottom ↑   the launcher      (the "home" gesture every phone has)
//   left   →   the overview
//   right  ←   the Control Center
//
// The top edge is not one of them: the bar is already there, and it already
// owns a reveal strip of its own for the autohide-over-fullscreen case.
//
// These only exist in touch mode. On a docked session they would be eight
// pixels of dead zone down three sides of the screen for a pointer that never
// wanted them, which is a worse trade than not having the gestures.
Scope {
    id: root

    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen

            required property ShellScreen modelData

            // One strip. `edge` names which side it sits on, and with it which
            // way the finger has to go.
            component Strip: PanelWindow {
                id: strip

                required property string edge

                signal swiped

                readonly property bool horizontal: strip.edge !== "bottom"

                screen: perScreen.modelData
                visible: Gestures.enabled
                color: "transparent"
                implicitWidth: Gestures.stripWidth
                implicitHeight: Gestures.stripWidth

                anchors {
                    left: strip.edge !== "right"
                    right: strip.edge !== "left"
                    bottom: true
                    // A vertical strip runs the height of the screen; the
                    // bottom one runs its width. Anchoring to three sides and
                    // letting the implicit size fill in the fourth is how a
                    // layer surface says that.
                    top: strip.horizontal
                }

                // Never reserve space, and never push a window around: this is
                // a listening post, not furniture.
                exclusionMode: ExclusionMode.Ignore
                exclusiveZone: 0

                WlrLayershell.namespace: "qshell:edge"
                // Top, not Overlay, so the keyboard (Overlay) covers the
                // bottom strip while it is up — swiping for the launcher from
                // underneath the space bar is not a thing anyone means to do.
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                MouseArea {
                    id: area

                    property real ox: 0
                    property real oy: 0
                    // Latched for the duration of one contact, so a long drag
                    // fires once instead of once per frame past the threshold.
                    property bool fired: false

                    anchors.fill: parent
                    // The strip has to keep the finger after the press, because
                    // the whole gesture happens off the strip — it is eight
                    // pixels wide and the swipe is fifty-five.
                    preventStealing: true

                    onPressed: mouse => {
                        area.ox = mouse.x;
                        area.oy = mouse.y;
                        area.fired = false;
                    }

                    onReleased: area.fired = false

                    onPositionChanged: mouse => {
                        if (area.fired)
                            return;
                        const dx = mouse.x - area.ox;
                        const dy = mouse.y - area.oy;
                        // Fires the moment the threshold is crossed rather
                        // than on release: a gesture that only resolves when
                        // you lift feels like it did not take.
                        let ok = false;
                        if (strip.edge === "bottom")
                            ok = dy <= -Gestures.threshold && Math.abs(dy) > Math.abs(dx);
                        else if (strip.edge === "left")
                            ok = dx >= Gestures.threshold && Math.abs(dx) > Math.abs(dy);
                        else
                            ok = dx <= -Gestures.threshold && Math.abs(dx) > Math.abs(dy);
                        if (ok) {
                            area.fired = true;
                            strip.swiped();
                        }
                    }
                }
            }

            Strip {
                edge: "bottom"
                onSwiped: Gestures.launcherRequested()
            }

            Strip {
                edge: "left"
                onSwiped: Gestures.overviewRequested()
            }

            Strip {
                edge: "right"
                onSwiped: Gestures.controlRequested()
            }
        }
    }
}
