import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.components

// One entry of a tray DBus menu, its submenu expanding inline underneath.
// Recursive through the Loader, so nesting keeps working at any depth — the
// old fixed two-level copy silently fired-and-closed anything deeper, which
// made third-level entries look like broken leaf actions.
Column {
    id: root

    required property var entry
    property int depth: 0
    property var popouts: null
    // Managed imperatively by TrayMenu's keyboard nav.
    property bool navLit: false

    property bool expanded: false

    readonly property int inset: depth * Appearance.s(14)

    width: parent.width

    MenuSeparator {
        visible: root.entry.isSeparator
        x: root.inset
        width: parent.width - x
    }

    Item {
        visible: !root.entry.isSeparator
        width: parent.width
        height: root.depth > 0 ? Appearance.s(30) : Appearance.s(34)

        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: Theme.surfaceHoverBg
            visible: root.navLit
        }

        StateLayer {
            enabled: root.entry.enabled
            radius: Appearance.rounding.normal
            color: Theme.surfaceFg
            onClicked: root.activate()
        }

        FIcon {
            id: checkGlyph

            x: root.inset + Appearance.s(8)
            anchors.verticalCenter: parent.verticalCenter
            visible: root.entry.checkState !== Qt.Unchecked
            icon: root.entry.checkState === Qt.Checked ? "checkmark_alt" : "minus"
            color: Theme.accent
            font.pixelSize: Appearance.font.size.small
        }

        IconImage {
            id: entryIcon

            x: root.inset + Appearance.s(8)
            anchors.verticalCenter: parent.verticalCenter
            visible: !checkGlyph.visible && root.entry.icon !== ""
            implicitSize: Appearance.s(14)
            source: root.entry.icon
        }

        StyledText {
            anchors.left: parent.left
            anchors.leftMargin: root.inset + ((checkGlyph.visible || entryIcon.visible) ? Appearance.s(28) : Appearance.s(10))
            anchors.right: chevron.visible ? chevron.left : parent.right
            anchors.rightMargin: Appearance.s(8)
            anchors.verticalCenter: parent.verticalCenter
            text: root.entry.text || "…"
            color: root.entry.enabled ? Theme.surfaceFg : Theme.surfaceFgDim
            font.pixelSize: Appearance.font.size.small
            elide: Text.ElideRight
        }

        FIcon {
            id: chevron

            anchors.right: parent.right
            anchors.rightMargin: Appearance.s(10)
            anchors.verticalCenter: parent.verticalCenter
            visible: root.entry.hasChildren
            icon: root.expanded ? "chevron_up" : "chevron_down"
            color: Theme.surfaceFgDim
            font.pixelSize: Appearance.font.size.small
        }
    }

    function activate(): void {
        if (root.entry.hasChildren) {
            root.expanded = !root.expanded;
        } else {
            root.entry.triggered();
            root.popouts?.close();
        }
    }

    // The visible, actionable rows of this subtree in display order — TrayMenu
    // flattens these across all entries so arrows walk into expanded submenus
    // instead of dead-ending at the top level.
    function navItems(): var {
        let out = [];
        if (!root.entry.isSeparator && root.entry.enabled)
            out.push(root);
        if (root.expanded && subLoader.item)
            out = out.concat(subLoader.item.collect());
        return out;
    }

    Loader {
        id: subLoader

        active: root.expanded
        visible: active
        width: parent.width

        sourceComponent: Column {
            width: root.width

            function collect(): var {
                let out = [];
                for (let i = 0; i < subRepeater.count; i++) {
                    const l = subRepeater.itemAt(i);
                    if (l?.item?.navItems)
                        out = out.concat(l.item.navItems());
                }
                return out;
            }

            QsMenuOpener {
                id: subOpener

                menu: root.entry
            }

            Repeater {
                id: subRepeater

                model: subOpener.children

                // Loaded by URL, not by type: the QML compiler refuses a
                // component that statically instantiates itself ("instantiated
                // recursively"), so the recursion has to be invisible to it.
                Loader {
                    required property var modelData

                    width: parent.width
                    Component.onCompleted: setSource("TrayMenuEntry.qml", {
                        entry: modelData,
                        depth: root.depth + 1,
                        popouts: root.popouts
                    })
                }
            }
        }
    }
}
