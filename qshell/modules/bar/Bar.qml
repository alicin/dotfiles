import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.modules.bar.popouts

// Top bar, one per monitor. Transparent chrome drawn over the wallpaper:
// workspaces left, clock center, status modules right (same layout as the
// old AGS shell). Each screen gets its own Popouts host for the dropdown
// menus.
Scope {
    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen

            required property ShellScreen modelData

            PanelWindow {
                id: win

                screen: perScreen.modelData
                color: "transparent"
                implicitHeight: Appearance.sizes.barHeight

                anchors {
                    left: true
                    top: true
                    right: true
                }

                WlrLayershell.namespace: "qshell:bar"

                // Lives here, not in the Control Center that toggles it: the
                // inhibitor needs a mapped window, and the menu is destroyed
                // on close. The bar is the only always-present surface.
                IdleInhibitor {
                    window: win
                    enabled: Idle.inhibited
                }

                Item {
                    anchors.fill: parent
                    anchors.leftMargin: Appearance.s(10)
                    anchors.rightMargin: Appearance.s(10)

                    // Subtle macOS-menubar-style drop shadow under everything
                    // on the bar (one layer pass for all icons/text).
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: "#000000"
                        shadowOpacity: 0.45
                        shadowBlur: 0.12
                        shadowVerticalOffset: 1
                        shadowHorizontalOffset: 0
                    }

                    Workspaces {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Appearance.s(2)

                        Tray {
                            popouts: popouts
                        }

                        KdecStatus {
                            id: kdecMod

                            popouts: popouts
                        }

                        BtStatus {
                            id: btMod

                            popouts: popouts
                        }

                        WifiStatus {
                            id: wifiMod

                            popouts: popouts
                        }

                        VolumeStatus {
                            id: volMod

                            popouts: popouts
                        }

                        BatteryStatus {
                            id: batMod

                            popouts: popouts
                        }

                        ControlStatus {
                            id: ctrlMod

                            popouts: popouts
                        }

                        NotifsStatus {
                            id: notifMod

                            popouts: popouts
                        }

                        Clock {}
                    }
                }
            }

            Popouts {
                id: popouts

                barWindow: win
            }

            // `qs ipc -c qshell call popouts toggle wifi` — debugging/keybind
            // hook. (With multiple screens the last bar registers the target.)
            IpcHandler {
                target: "popouts"

                function toggle(name: string): string {
                    const anchors = {
                        notifs: notifMod,
                        bluetooth: btMod,
                        wifi: wifiMod,
                        audio: volMod,
                        battery: batMod,
                        kdeconnect: kdecMod,
                        control: ctrlMod
                    };
                    const item = anchors[name];
                    if (!item)
                        return `unknown menu "${name}"`;
                    popouts.toggle(name, item, null);
                    return "ok";
                }
            }
        }
    }
}
