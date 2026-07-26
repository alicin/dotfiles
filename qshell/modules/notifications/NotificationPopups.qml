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

                    width: stack.width
                    wrapper: modelData

                    Timer {
                        interval: (card.modelData.n?.expireTimeout ?? 0) > 0 ? card.modelData.n.expireTimeout : 6000
                        running: (card.modelData.n?.urgency ?? NotificationUrgency.Normal) !== NotificationUrgency.Critical
                        onTriggered: Notifs.dropPopup(card.modelData)
                    }
                }
            }
        }
    }
}
