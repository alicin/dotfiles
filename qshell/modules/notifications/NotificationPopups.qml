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

        mask: Region {
            item: Notifs.popupsHidden ? null : stack
        }

        Column {
            id: stack

            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: Appearance.s(8)
            anchors.rightMargin: Appearance.s(12)
            width: Appearance.s(380)
            spacing: Appearance.s(8)
            opacity: Notifs.popupsHidden ? 0 : 1

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

                    width: stack.width
                    wrapper: modelData
                    // Dismissals (× or body-click) slide out the way they
                    // slid in, instead of the delegate vanishing same-frame.
                    requestDismiss: () => card.exit(true)

                    function exit(dismiss: bool): void {
                        if (card.exiting)
                            return;
                        card.exiting = true;
                        exitAnim.dismiss = dismiss;
                        exitAnim.start();
                    }

                    // If the delegate dies mid-exit (a notification burst
                    // evicting this wrapper from the popup cap), a pending
                    // dismissal still completes — the intent is consumed in
                    // onFinished so the normal path can't double-fire.
                    Component.onDestruction: {
                        if (exitAnim.dismiss)
                            card.modelData.n?.dismiss();
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
                        // unhovered restarts the full interval.
                        running: (card.modelData.n?.urgency ?? NotificationUrgency.Normal) !== NotificationUrgency.Critical && !card.hovered && !card.exiting
                        onTriggered: card.exit(false)
                    }
                }
            }
        }
    }
}
