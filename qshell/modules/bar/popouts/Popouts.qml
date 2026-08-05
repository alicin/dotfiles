import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services
import qs.modules.control

// Dropdown host for the bar: one permanently-mapped strip window under the
// bar, input-masked to the panel while open. The panel slides down under the
// clicked module and *morphs* (x/width/height, M3 emphasized) when switching
// between menus — caelestia popouts, simplified.
Scope {
    id: root

    required property var barWindow

    property string current: ""
    // Outlives `current` for the length of the close animation — the Loader
    // keys off this so the menu doesn't blank out mid-fade.
    property string shown: ""
    // The SystemTrayItem for tray menus; the Control Center's initial page
    // name for "control".
    property var context: null
    property real anchorX: 0

    readonly property bool open: current !== ""

    onOpenChanged: Notifs.menuOpen = open

    function toggle(name: string, item: Item, ctx: var): void {
        if (current === name) {
            close();
            return;
        }
        if (ctx !== undefined && ctx !== null)
            context = ctx;
        anchorX = item.mapToItem(null, item.width / 2, 0).x;
        current = name;
        shown = name;
    }

    // Opening the Control Center *on a page*. Separate from toggle() so a
    // second press of the sound keybind while Bluetooth is showing switches
    // pages instead of dismissing the whole panel — only the same page again
    // closes it.
    function openControl(page: string, item: Item): void {
        if (current === "control" && context === page) {
            close();
            return;
        }
        context = page;
        anchorX = item.mapToItem(null, item.width / 2, 0).x;
        current = "control";
        shown = "control";
    }

    function close(): void {
        current = "";
    }

    // A capture is starting: get off the screen. Not just cosmetic — a popout
    // holding a focus grab eats the first click meant for slurp, so an area
    // selection never sees the press that would have started it.
    Connections {
        target: Capture

        function onClosePopouts(): void {
            root.close();
        }
    }

    PanelWindow {
        id: win

        screen: root.barWindow.screen
        color: "transparent"
        // Constant, not panel.height + margin: sizing the layer surface to its
        // content made the surface resize on every open, and the `qshell:.*`
        // layer rule animates that — so the panel got revealed progressively
        // and read as a grow. Tall enough for the longest menu; input is masked
        // to the panel, so the extra transparent area costs nothing. Same
        // approach as the launcher window.
        //
        // The Wi-Fi menu is what sets this: with the tailnet's devices and
        // exit-node picker under the networks it now runs to roughly 870 at
        // its worst (six networks, six peers, two VPN profiles), and a menu
        // that overflows this surface is silently *clipped* — there is no
        // scrolling at the menu level, so rows simply stop being drawn.
        implicitHeight: Appearance.s(920)
        exclusiveZone: 0

        anchors {
            top: true
            left: true
            right: true
        }

        WlrLayershell.namespace: "qshell:popouts"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        mask: Region {
            item: root.open ? panel : null
        }

        HyprlandFocusGrab {
            active: root.open
            windows: [win, root.barWindow]
            onCleared: root.close()
        }

        // Each menu appears in place under its own icon — geometry snaps on
        // first open (the panel must materialize under the clicked module, not
        // glide over from wherever it last was), then scales+fades in over
        // 300ms, growing from the top edge so it reads as coming out of the
        // bar. Once fully open, x/width/height DO animate — switching menus
        // morphs the panel between them instead of teleporting it.
        //
        // The window height is deliberately NOT content-derived: sizing the
        // layer surface to the panel made the surface resize on every open, and
        // the `qshell:.*` layer rule animates that — a second, laggier grow
        // underneath this one.
        Elevation {
            anchors.fill: panel
            radius: panel.radius
            level: 4
            visible: panel.visible
            opacity: panel.opacity
            scale: panel.scale
            transformOrigin: panel.transformOrigin
        }

        Rectangle {
            id: panel

            readonly property int pad: Appearance.s(12)

            // 0 closed, 1 open — drives opacity and scale together so they
            // can't drift apart.
            property real anim: root.open ? 1 : 0

            // Geometry animates only in this state; during the open/close
            // animation it must snap (see the comment above).
            readonly property bool settled: root.open && anim === 1

            onAnimChanged: {
                if (anim <= 0.001 && !root.open)
                    root.shown = "";
            }

            Behavior on anim {
                Anim {
                    // Deceleration is an entrance curve; on dismiss it read as
                    // the panel lingering. Out goes faster, on an exit curve.
                    duration: root.open ? Appearance.d(300) : Appearance.anim.durations.expressiveDefaultEffects
                    curve: root.open ? Appearance.anim.curves.emphasizedDecel : Appearance.anim.curves.expressiveDefaultEffects
                }
            }

            // The anchor is what animates, not x itself: x derives from both
            // the anchor and width, and a Behavior on x would be restarted by
            // every frame of the width morph — the panel then crawls through
            // the emphasized curve's flat start over and over and lurches in
            // late. With the anchor and width each retargeting exactly once,
            // x re-derives smoothly per frame and the edge clamp holds
            // throughout the morph.
            property real ax: root.anchorX

            Behavior on ax {
                enabled: panel.settled

                Anim {
                    duration: Appearance.d(300)
                    curve: Appearance.anim.curves.emphasized
                }
            }

            x: Math.max(Appearance.s(8), Math.min(ax - width / 2, win.width - width - Appearance.s(8)))
            y: Appearance.s(6)
            visible: anim > 0.001
            opacity: anim
            scale: 0.9 + 0.1 * anim
            transformOrigin: Item.Top

            width: (loader.item?.implicitWidth ?? 0) + pad * 2
            height: (loader.item?.implicitHeight ?? 0) + pad * 2
            radius: Appearance.sizes.menuRadius
            color: Theme.surfaceBg
            border.width: 1
            border.color: Theme.surfaceBorder
            // Mid-morph the new menu is already at full size while the panel
            // is still en route — keep it from poking past the edges. (Content
            // is inset by `pad`, so the rectangular clip never shows against
            // the rounded corners in steady state.)
            clip: true

            Behavior on width {
                enabled: panel.settled

                Anim {
                    duration: Appearance.d(300)
                    curve: Appearance.anim.curves.emphasized
                }
            }

            Behavior on height {
                enabled: panel.settled

                Anim {
                    duration: Appearance.d(300)
                    curve: Appearance.anim.curves.emphasized
                }
            }

            FocusScope {
                anchors.fill: parent
                focus: true
                // Esc gives the menu first refusal (the Control Center pops a
                // detail page back to home) and only then dismisses the panel.
                Keys.onEscapePressed: {
                    if (loader.item?.navBack?.())
                        return;
                    root.close();
                }
                // Optional per-menu keyboard nav: menus that define
                // navMove/navActivate/navRemove get arrows, Enter and Delete;
                // the rest ignore them. NB a focused TextInput only consumes
                // *character* keys on its own — the wifi password field
                // explicitly swallows arrows and Return so typing never
                // navigates (see its Keys handlers).
                Keys.onUpPressed: loader.item?.navMove?.(-1)
                Keys.onDownPressed: loader.item?.navMove?.(1)
                Keys.onReturnPressed: loader.item?.navActivate?.()
                Keys.onEnterPressed: loader.item?.navActivate?.()
                Keys.onDeletePressed: loader.item?.navRemove?.()

                Loader {
                    id: loader

                    x: panel.pad
                    y: panel.pad
                    active: root.shown !== ""

                    sourceComponent: {
                        switch (root.shown.startsWith("tray:") ? "tray" : root.shown) {
                        case "wifi":
                            return wifiMenu;
                        case "battery":
                            return batteryMenu;
                        case "notifs":
                            return notifsMenu;
                        case "calendar":
                            return calendarMenu;
                        case "control":
                            return controlMenu;
                        case "tray":
                            return trayMenu;
                        default:
                            return null;
                        }
                    }
                }
            }
        }

        Component {
            id: wifiMenu

            WifiMenu {}
        }

        Component {
            id: batteryMenu

            BatteryMenu {}
        }

        Component {
            id: notifsMenu

            NotifsMenu {}
        }

        Component {
            id: calendarMenu

            CalendarMenu {}
        }

        Component {
            id: controlMenu

            ControlCenter {
                // `context` doubles as the tray item for tray menus, so only
                // read it while the Control Center is the one showing.
                requestedPage: root.shown === "control" ? (root.context ?? "") : ""
            }
        }

        Component {
            id: trayMenu

            TrayMenu {
                item: root.context
                popouts: root
            }
        }
    }
}
