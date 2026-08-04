import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.config
import qs.components

// Custom-drawn DBus menu for a tray item; entries expand their submenus
// inline (TrayMenuEntry, recursive).
Column {
    id: root

    property SystemTrayItem item: null
    property var popouts: null

    // Keyboard nav (arrows + Enter, driven by the Popouts FocusScope) walks
    // the *visible delegate tree* — expanded submenu entries included, at any
    // depth — not just the top-level model. Identity-based, so a collapse
    // destroying the selected row self-heals on the next move.
    property var navItem: null

    // Hover-slide can retarget this same instance to another tray icon (only
    // `item` rebinds) — the old menu's highlight must not survive onto an
    // arbitrary row of the new one.
    onItemChanged: {
        clearLit();
        navItem = null;
    }

    function clearLit(): void {
        // The lit row may already be destroyed (submenu collapsed).
        try {
            if (navItem)
                navItem.navLit = false;
        } catch (e) {}
    }

    function flatNav(): var {
        let out = [];
        for (let i = 0; i < entries.count; i++) {
            const it = entries.itemAt(i);
            if (it?.navItems)
                out = out.concat(it.navItems());
        }
        return out;
    }

    function navMove(d: int): void {
        const items = flatNav();
        if (items.length === 0)
            return;
        let idx = items.indexOf(navItem);
        idx = idx < 0 ? (d > 0 ? 0 : items.length - 1) : (idx + d + items.length) % items.length;
        clearLit();
        navItem = items[idx];
        navItem.navLit = true;
    }

    function navActivate(): void {
        navItem?.activate();
    }

    width: Appearance.s(240)
    spacing: 0

    QsMenuOpener {
        id: opener

        menu: root.item?.menu ?? null
    }

    // The tray is a row of monochrome lookalikes revealed on hover — nothing
    // else names whose menu this is.
    StyledText {
        visible: (opener.children?.values.length ?? 0) > 0
        width: parent.width
        height: Appearance.s(24)
        text: root.item?.title || root.item?.id || ""
        color: Theme.surfaceFgDim
        font.pixelSize: Appearance.font.size.small
        elide: Text.ElideRight
    }

    MenuSeparator {
        visible: (opener.children?.values.length ?? 0) > 0
        width: parent.width
    }

    StyledText {
        visible: (opener.children?.values.length ?? 0) === 0
        height: Appearance.sizes.menuRowHeight
        text: root.item?.title || "No menu"
        color: Theme.surfaceFgDim
    }

    Repeater {
        id: entries

        model: opener.children

        TrayMenuEntry {
            required property var modelData

            entry: modelData
            popouts: root.popouts
        }
    }
}
