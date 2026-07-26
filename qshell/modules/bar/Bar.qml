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

                    // macOS-menubar-style drop shadow under everything on the
                    // bar (one layer pass for all icons/text). Heavy on
                    // purpose: the bar is transparent chrome over an arbitrary
                    // wallpaper, and a subtle shadow loses the fight against a
                    // bright or busy one.
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: "#000000"
                        shadowOpacity: 0.75
                        shadowBlur: 0.3
                        shadowVerticalOffset: 2
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

                        // Left of the tray ellipsis: the Row is right-anchored,
                        // so anything ahead of the tray keeps every other
                        // module in place when these appear and vanish.
                        PrivacyStatus {}

                        Tray {
                            popouts: popouts
                        }

                        WifiStatus {
                            id: wifiMod

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
                    // Sound, Bluetooth and KDE Connect no longer have their own
                    // bar module — the names still work and open the Control
                    // Center straight onto that page, so existing keybinds
                    // didn't have to change. "control" is the home screen, and
                    // goes through the same path so calling it from a page
                    // navigates back rather than dismissing.
                    const pages = {
                        control: "",
                        audio: "audio",
                        bluetooth: "bluetooth",
                        kdeconnect: "kdeconnect"
                    };
                    if (name in pages) {
                        popouts.openControl(pages[name], ctrlMod);
                        return "ok";
                    }

                    const anchors = {
                        notifs: notifMod,
                        wifi: wifiMod,
                        battery: batMod
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
