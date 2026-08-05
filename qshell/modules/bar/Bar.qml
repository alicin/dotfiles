import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services
import qs.modules.bar.popouts

// Top bar, one per monitor. Transparent chrome drawn over the wallpaper:
// workspaces left, clock center, status modules right (same layout as the
// old AGS shell). Each screen gets its own Popouts host for the dropdown
// menus.
Scope {
    id: root

    // Screen name → that screen's bar Scope, so the IPC handler below can pick
    // the bar on the *focused* monitor. Plain object, mutated in place: it's
    // only ever read inside the handler's functions, never bound to.
    property var bars: ({})

    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen

            required property ShellScreen modelData

            readonly property var pops: popouts
            readonly property var mods: ({
                    wifi: wifiMod,
                    battery: batMod,
                    control: ctrlMod,
                    notifs: notifMod,
                    calendar: clockMod
                })

            Component.onCompleted: root.bars[modelData.name] = perScreen
            // By value, not by name: on monitor unplug the ShellScreen dies
            // before this Scope does, so modelData is already null here — and
            // a stale entry would hand the IPC handler a dead bar.
            Component.onDestruction: {
                for (const k in root.bars)
                    if (root.bars[k] === perScreen)
                        delete root.bars[k];
            }

            // Whether this monitor's active workspace holds a fullscreen
            // window. Hyprland only re-emits workspace state on its own
            // events, so the fullscreen event refreshes it explicitly.
            readonly property var mon: Hyprland.monitorFor(perScreen.modelData)
            readonly property bool fullscreen: mon?.activeWorkspace?.hasFullscreen ?? false

            Connections {
                target: Hyprland

                function onRawEvent(event: HyprlandEvent): void {
                    if (event.name === "fullscreen")
                        Hyprland.refreshWorkspaces();
                }
            }

            PanelWindow {
                id: win

                // Autohide over fullscreen: the bar slides up out of the way
                // and a strip of pixels at the very top edge brings it back,
                // the way every full-screen video player on this machine
                // expects. Popouts hold it down — a menu whose anchor slid
                // away is worse than the bar staying put.
                //
                // TWO hover sources, not one: the strip is the only thing that
                // can be hovered while hidden (it is the whole input region),
                // but the moment it reveals the bar the pointer is free to move
                // off those two pixels onto an actual module — and keying the
                // reveal on the strip alone would then snap the bar shut under
                // the cursor before it arrived anywhere.
                readonly property bool revealed: !perScreen.fullscreen || hotStrip.hovered || barHover.hovered || popouts.open

                screen: perScreen.modelData
                color: "transparent"
                implicitHeight: Appearance.sizes.barHeight
                // Fullscreen windows ignore exclusive zones anyway; dropping
                // it keeps the *tiled* layout from reflowing when a
                // neighbouring workspace goes fullscreen.
                exclusiveZone: perScreen.fullscreen ? 0 : Appearance.sizes.barHeight

                anchors {
                    left: true
                    top: true
                    right: true
                }

                WlrLayershell.namespace: "qshell:bar"

                // Revealed: no mask at all, so the whole surface takes input —
                // masking to `content` would have made the 10px margin at each
                // screen edge click-through, undoing the edge-slam targeting
                // the modules' hit slop exists for.
                //
                // Hidden: the input region shrinks to the top edge strip. An
                // empty mask would be click-through but would also stop
                // delivering the hover that brings the bar back, and a
                // full-height one would eat clicks meant for the video.
                mask: win.revealed ? null : hotRegion

                Region {
                    id: hotRegion

                    item: hotStripItem
                }

                // Lives here, not in the Control Center that toggles it: the
                // inhibitor needs a mapped window, and the menu is destroyed
                // on close. The bar is the only always-present surface.
                //
                // Recording holds it too: hypridle could dim, lock or suspend
                // mid-take — straight into the clip.
                IdleInhibitor {
                    window: win
                    enabled: Idle.active
                }

                Item {
                    id: hotStripItem

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: Math.max(1, Appearance.s(2))

                    HoverHandler {
                        id: hotStrip
                    }
                }

                // Whole-window hover, which only ever fires while the bar is
                // revealed (hidden, the input region is the strip above).
                // Keeps it down for as long as the pointer is on it.
                HoverHandler {
                    id: barHover
                }

                // Geometry stays put (the input mask is derived from it and a
                // Region doesn't follow transforms); the strip *inside* is
                // what slides away.
                Item {
                    id: content

                    anchors.fill: parent
                    anchors.leftMargin: Appearance.s(10)
                    anchors.rightMargin: Appearance.s(10)

                    Item {
                        id: slider

                        width: parent.width
                        height: parent.height
                        y: win.revealed ? 0 : -Appearance.sizes.barHeight
                        opacity: win.revealed ? 1 : 0

                        Behavior on y {
                            Anim {
                                duration: Appearance.anim.durations.expressiveFastSpatial
                                curve: Appearance.anim.curves.emphasized
                            }
                        }

                        Behavior on opacity {
                            Anim {
                                duration: Appearance.anim.durations.expressiveFastEffects
                            }
                        }

                        // macOS-menubar-style drop shadow under everything on
                        // the bar (one layer pass for all icons/text). Heavy on
                        // purpose: the bar is transparent chrome over an
                        // arbitrary wallpaper, and a subtle shadow loses the
                        // fight against a bright or busy one.
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
                            id: wsMod

                            screen: perScreen.modelData
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // The bar's empty middle, which until now was empty in
                        // the literal sense. It names the focused window and
                        // takes the brightness wheel — the volume gesture's
                        // missing twin, given the one target on the bar big
                        // enough to hit without aiming.
                        Item {
                            id: centre

                            anchors.left: wsMod.right
                            anchors.leftMargin: Appearance.s(12)
                            anchors.right: statusRow.left
                            anchors.rightMargin: Appearance.s(12)
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            // A negative width (narrow screen, full status row)
                            // makes Text elide against nothing and warn.
                            visible: width > Appearance.s(60)

                            // Only the focused monitor names a window: every
                            // other bar would otherwise repeat a title for a
                            // window that isn't on it.
                            readonly property bool focused: Hyprland.focusedMonitor?.name === perScreen.modelData.name
                            readonly property string title: {
                                const t = Hyprland.activeToplevel;
                                if (!t)
                                    return "";
                                return t.title || t.wayland?.title || t.lastIpcObject?.title || "";
                            }

                            WheelDetent {
                                // Same 4%-per-notch feel as the volume gesture
                                // next door, and the same explicit OSD: there's
                                // no visible slider here either.
                                onMoved: notches => {
                                    Brightness.setDisplay(Brightness.display + notches * 0.04);
                                    Osd.show("brightness");
                                }
                            }

                            StyledText {
                                anchors.centerIn: parent
                                width: Math.min(implicitWidth, parent.width)
                                horizontalAlignment: Text.AlignHCenter
                                visible: centre.focused && text !== ""
                                text: centre.title
                                color: Theme.barFgDim
                                elide: Text.ElideRight
                            }
                        }

                        Row {
                            id: statusRow

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Appearance.s(2)

                            // Left of the tray ellipsis: the Row is
                            // right-anchored, so anything ahead of the tray
                            // keeps every other module in place when these
                            // appear and vanish.
                            RecordStatus {
                                tooltip: tip
                            }

                            MediaStatus {
                                tooltip: tip
                            }

                            PrivacyStatus {}

                            Tray {
                                popouts: popouts
                                tooltip: tip
                            }

                            WifiStatus {
                                id: wifiMod

                                popouts: popouts
                                tooltip: tip
                            }

                            // Immediately left of the Control Center glyph it
                            // used to be a tint on, and collapsed to nothing
                            // the rest of the time.
                            AwakeStatus {
                                tooltip: tip
                            }

                            ControlStatus {
                                id: ctrlMod

                                popouts: popouts
                            }

                            NotifsStatus {
                                id: notifMod

                                popouts: popouts
                            }

                            // Last before the clock: the two things you glance
                            // at without meaning to click sit together at the
                            // end of the row.
                            BatteryStatus {
                                id: batMod

                                popouts: popouts
                                tooltip: tip
                            }

                            Clock {
                                id: clockMod

                                popouts: popouts
                                tooltip: tip
                            }
                        }
                    }
                }
            }

            Popouts {
                id: popouts

                barWindow: win
            }

            BarTooltip {
                id: tip

                barWindow: win
            }
        }
    }

    // `qs ipc -c qshell call popouts toggle wifi` — debugging/keybind hook.
    // One handler for all screens, resolving the focused monitor's bar per
    // call: it used to live inside the Variants, where the last screen to
    // register silently captured every keybind's menus.
    IpcHandler {
        target: "popouts"

        function toggle(name: string): string {
            const bar = root.bars[Hyprland.focusedMonitor?.name] ?? Object.values(root.bars)[0];
            if (!bar)
                return "no bar";

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
                kdeconnect: "kdeconnect",
                display: "display"
            };
            if (name in pages) {
                bar.pops.openControl(pages[name], bar.mods.control);
                return "ok";
            }

            const item = bar.mods[name];
            if (!item)
                return `unknown menu "${name}"`;
            bar.pops.toggle(name, item, null);
            return "ok";
        }
    }
}
