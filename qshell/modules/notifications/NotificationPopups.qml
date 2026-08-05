import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import qs.config
import qs.components
import qs.services

// Notification popups: top-right on the focused screen, slide in from the
// right, auto-expire (critical ones stick until dismissed).
Scope {
    PanelWindow {
        id: win

        // Pinned per toast batch: assigned when the stack goes from empty to
        // non-empty and held until it drains (the assignment severs this live
        // binding on first use, on purpose) — a toast used to teleport to the
        // other monitor mid-read when the cursor crossed screens.
        readonly property bool haveToasts: Notifs.popups.length > 0

        onHaveToastsChanged: {
            if (haveToasts)
                win.screen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null;
        }

        // Auto-DND for recordings, scoped to what is actually being recorded:
        // this window's own footprint is exactly where toasts appear, so a
        // region recording in the other corner leaves them alone while a
        // full-screen take hides them. A notification burned into a clip can't
        // be edited out afterwards.
        readonly property bool inShot: Capture.covers(win.screen ? win.screen.x + win.screen.width - win.width : 0, win.screen?.y ?? 0, win.width, win.height)

        readonly property bool hidden: Notifs.popupsHidden || win.inShot

        // Only while a reply field has focus: a toast that took the keyboard
        // on sight would swallow whatever you were typing into the window
        // underneath it.
        readonly property bool replying: stack.replyCount > 0

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null
        color: "transparent"
        implicitWidth: Appearance.s(404)
        implicitHeight: Appearance.s(740)
        exclusiveZone: 0

        anchors {
            top: true
            right: true
        }

        WlrLayershell.namespace: "qshell:notifs"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: win.replying ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        mask: Region {
            item: win.hidden ? null : stack
        }

        Column {
            id: stack

            // How many cards have a focused reply field. A counter rather than
            // a flag: two toasts can be on screen and focus moves between them
            // in either order.
            property int replyCount: 0

            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: Appearance.s(8)
            anchors.rightMargin: Appearance.s(12)
            width: Appearance.s(380)
            spacing: Appearance.s(8)
            opacity: win.hidden ? 0 : 1

            Behavior on opacity {
                Anim {
                    duration: Appearance.anim.durations.expressiveDefaultEffects
                    curve: Appearance.anim.curves.expressiveDefaultEffects
                }
            }

            add: Transition {
                Anim {
                    properties: "x"
                    from: Appearance.s(420)
                    curve: Appearance.anim.curves.emphasizedDecel
                }

                Anim {
                    properties: "opacity"
                    from: 0
                    to: 1
                    duration: Appearance.anim.durations.expressiveSlowEffects
                }
            }

            move: Transition {
                Anim {
                    properties: "y"
                    curve: Appearance.anim.curves.emphasized
                }
            }

            Repeater {
                model: ScriptModel {
                    values: Notifs.popups
                }

                NotificationCard {
                    id: card

                    required property var modelData

                    // Guards double-starts and gates the expiry timer during
                    // the exit slide.
                    property bool exiting: false

                    // Past this the release commits instead of springing back.
                    readonly property real dismissAt: width * 0.35

                    width: stack.width
                    wrapper: modelData
                    // Dismissals (× or body-click) slide out the way they
                    // slid in, instead of the delegate vanishing same-frame.
                    requestDismiss: () => card.exit(true)

                    onReplyingChanged: stack.replyCount += replying ? 1 : -1

                    function exit(dismiss: bool): void {
                        if (card.exiting)
                            return;
                        card.exiting = true;
                        exitAnim.dismiss = dismiss;
                        exitAnim.start();
                    }

                    // Throw it off the right edge. The handler sits on the card
                    // itself and only claims the gesture past the drag
                    // threshold, so a plain click still reaches the MouseArea
                    // underneath and the action pills still work.
                    DragHandler {
                        id: drag

                        target: card
                        yAxis.enabled: false
                        xAxis.minimum: 0
                        cursorShape: Qt.ClosedHandCursor
                        enabled: !card.exiting

                        onActiveChanged: {
                            if (active)
                                return;
                            if (card.x > card.dismissAt)
                                card.exit(true);
                            else
                                springBack.restart();
                        }
                    }

                    // Fades as it goes, so a half-hearted drag visibly isn't
                    // committing to anything. Assigned rather than bound: the
                    // entrance transition and the exit animation both own this
                    // property at other moments, and a binding would fight
                    // them for it.
                    onXChanged: {
                        if (drag.active)
                            card.opacity = Math.max(0.25, 1 - card.x / (card.width * 0.9));
                    }

                    ParallelAnimation {
                        id: springBack

                        Anim {
                            target: card
                            property: "x"
                            to: 0
                            duration: Appearance.anim.durations.expressiveFastSpatial
                            curve: Appearance.anim.curves.emphasizedDecel
                        }

                        Anim {
                            target: card
                            property: "opacity"
                            to: 1
                            duration: Appearance.anim.durations.expressiveFastEffects
                        }
                    }

                    // If the delegate dies mid-exit (a notification burst
                    // evicting this wrapper from the popup cap), a pending
                    // dismissal still completes — the intent is consumed in
                    // onFinished so the normal path can't double-fire.
                    Component.onDestruction: {
                        if (exitAnim.dismiss)
                            card.modelData.n?.dismiss();
                        // A card destroyed while its reply field had focus
                        // would leave the window holding the keyboard forever.
                        if (card.replying)
                            stack.replyCount--;
                    }

                    ParallelAnimation {
                        id: exitAnim

                        // Whether to destroy the notification or just retire
                        // the toast into history.
                        property bool dismiss: false

                        onFinished: {
                            if (exitAnim.dismiss) {
                                exitAnim.dismiss = false;
                                card.modelData.n?.dismiss();
                            } else {
                                Notifs.dropPopup(card.modelData);
                            }
                        }

                        Anim {
                            target: card
                            property: "x"
                            to: Appearance.s(420)
                            duration: Appearance.anim.durations.expressiveDefaultEffects
                            curve: Appearance.anim.curves.emphasizedAccel
                        }

                        Anim {
                            target: card
                            property: "opacity"
                            to: 0
                            duration: Appearance.anim.durations.expressiveDefaultEffects
                        }
                    }

                    Timer {
                        interval: (card.modelData.n?.expireTimeout ?? 0) > 0 ? card.modelData.n.expireTimeout : 6000
                        // Paused while the pointer is over the card — a toast
                        // used to vanish mid-reach for its Open button. Going
                        // unhovered restarts the full interval. Also paused
                        // mid-drag and mid-reply, for the same reason.
                        running: (card.modelData.n?.urgency ?? NotificationUrgency.Normal) !== NotificationUrgency.Critical && !card.hovered && !card.exiting && !drag.active && !card.replying
                        onTriggered: card.exit(false)
                    }
                }
            }
        }
    }
}
