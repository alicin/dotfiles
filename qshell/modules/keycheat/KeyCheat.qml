import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.components

// Keyboard-shortcut cheat sheet, generated from the live Hyprland config.
//
// Replaces bin/keycheat-overlay.py, a standalone GTK4 + gtk4-layer-shell app
// that hardcoded a Catppuccin-Mocha palette. That was fine when the shell was
// always dark and wrong the moment it wasn't: on Latte it was a slab of #1b1c2b
// over a light desktop. Everything here draws from Theme/Appearance instead, so
// it retextures with `qs -c qshell ipc call theme set …` like every other
// surface, and it inherits the shell's motion tokens rather than appearing
// instantly.
//
// Source of truth is ~/.config/hypr/lua/binds.lua — the file Hyprland actually
// loads — parsed for `-- ▸ Group` headers and trailing `-- label` comments.
// watchChanges is on, so editing a bind updates the sheet without a reload.
//
// Toggle: `qs -c qshell ipc call keycheat toggle` (Super+/ via apps.lua).
Scope {
    id: root

    property bool open: false
    property var groups: []
    property bool parsed: false

    // Alias expansions, mirroring the `local M, MS, MC, MCS` block at the top of
    // binds.lua. If those ever gain a sibling, this is the one place to add it.
    readonly property var aliases: ({
            M: "Super",
            MS: "Super + Shift",
            MC: "Super + Ctrl",
            MCS: "Super + Ctrl + Shift",
            mod: "Super"
        })

    // Display sugar for key tokens that read badly as raw keysyms.
    readonly property var keymap: ({
            Return: "↵",
            slash: "/",
            backslash: "\\",
            grave: "`",
            comma: ",",
            period: ".",
            Delete: "Del",
            left: "←",
            right: "→",
            up: "↑",
            down: "↓",
            "mouse:272": "L-Click",
            "mouse:273": "R-Click",
            mouse_down: "Scroll ↓",
            mouse_up: "Scroll ↑",
            XF86AudioRaiseVolume: "Vol +",
            XF86AudioLowerVolume: "Vol −",
            XF86AudioMute: "Mute",
            XF86AudioMicMute: "Mic",
            XF86AudioPlay: "▶",
            XF86AudioStop: "■",
            XF86AudioPause: "⏸",
            XF86AudioPrev: "⏮",
            XF86AudioNext: "⏭"
        })

    readonly property var modifierTokens: ["Super", "Shift", "Ctrl", "Alt"]

    // Text editing lives in Toshy's keymaps, not in binds.lua, so it cannot be
    // parsed out of the config — it is listed by hand. Shown in PHYSICAL keys:
    // on this machine Toshy emits macOS Command from the physical Alt key, so
    // "Alt + C" is what the fingers do, whatever the app receives.
    readonly property var textGroup: ({
            name: "Text editing",
            rows: [
                {
                    combo: "Super + ← →",
                    label: "jump by word"
                },
                {
                    combo: "Super + Shift + ← →",
                    label: "select word"
                },
                {
                    combo: "Alt + ← →",
                    label: "line start / end"
                },
                {
                    combo: "Alt + Shift + ← →",
                    label: "select to line"
                },
                {
                    combo: "Alt + C / V / X",
                    label: "copy / paste / cut"
                },
                {
                    combo: "Alt + Z",
                    label: "undo · Alt+Shift+Z redo"
                },
                {
                    combo: "Alt + A / F / S",
                    label: "all / find / save"
                }
            ]
        })

    // ── Parsing ───────────────────────────────────────────────────────────
    // `MS .. " + Return"` → "Super + Shift + Return". Returns "" when any
    // fragment is neither an alias nor a literal, which drops binds built from
    // a runtime expression rather than showing a half-resolved combo.
    function resolveCombo(expr: string): string {
        const out = [];
        for (let part of expr.split("..")) {
            part = part.trim();
            if (root.aliases[part] !== undefined)
                out.push(root.aliases[part]);
            else if (part.length >= 2 && part[0] === '"' && part[part.length - 1] === '"')
                out.push(part.slice(1, -1));
            else
                return "";
        }
        return out.join("").trim();
    }

    function parse(text: string): var {
        const lines = (text ?? "").split("\n");
        const groups = [];
        let cur = null;
        let i = 0;

        while (i < lines.length) {
            const s = lines[i].trim();

            const header = s.match(/^--\s*▸\s*(.+)$/);
            if (header) {
                cur = {
                    name: header[1].trim(),
                    rows: []
                };
                groups.push(cur);
                i++;
                continue;
            }

            // The workspace binds are generated in a Lua loop, so there is no
            // per-key line to read a label off. Summarise the loop instead and
            // skip to its `end`.
            if (s.startsWith("for ws, key in pairs(ws_keys)")) {
                if (cur) {
                    cur.rows.push({
                        combo: "Super + 1…9",
                        label: "switch workspace"
                    });
                    cur.rows.push({
                        combo: "Super + Shift + 1…9",
                        label: "move window to workspace"
                    });
                }
                while (i < lines.length && lines[i].trim() !== "end")
                    i++;
                i++;
                continue;
            }

            const bind = s.match(/^hl\.bind\(\s*(.+?)\s*,/);
            if (bind && cur) {
                const combo = root.resolveCombo(bind[1]);
                const label = lines[i].match(/.*\s--\s*(.+?)\s*$/);
                if (combo && label)
                    cur.rows.push({
                        combo: combo,
                        label: label[1]
                    });
            }

            // Gestures carry no trailing label and no key combo — the Python
            // overlay parsed only hl.bind, so the Gestures group came out empty
            // and got dropped. Synthesise a readable row from the table fields.
            const gest = s.match(/^hl\.gesture\(\{(.+)\}\)/);
            if (gest && cur) {
                const body = gest[1];
                const fingers = body.match(/fingers\s*=\s*(\d+)/);
                const dir = body.match(/direction\s*=\s*"([^"]+)"/);
                const act = body.match(/action\s*=\s*"([^"]+)"/);
                if (fingers && act)
                    cur.rows.push({
                        combo: `${fingers[1]} fingers${dir ? " · " + dir[1] : ""}`,
                        label: act[1]
                    });
            }

            i++;
        }

        // Drop duplicates within a group (Hyprland matches keysyms
        // case-insensitively, so binds.lua legitimately registers some twice)
        // and drop groups that produced nothing.
        const out = [];
        for (const g of groups) {
            const seen = {};
            const uniq = [];
            for (const r of g.rows) {
                const k = r.combo + "\t" + r.label;
                if (seen[k])
                    continue;
                seen[k] = true;
                uniq.push(r);
            }
            if (uniq.length > 0)
                out.push({
                    name: g.name,
                    rows: uniq
                });
        }
        return out;
    }

    function reload(): void {
        root.groups = [root.textGroup, ...root.parse(bindsFile.text())];
        root.parsed = true;
    }

    // Group headers double as prose in binds.lua — "Gestures (touchpad — and,
    // through the bridge, the touchscreen)" is a useful comment and a terrible
    // card title. Keep the part before the parenthetical.
    function shortName(name: string): string {
        return name.split(" (")[0].trim();
    }

    // Balanced masonry. A plain Flow is row-major, so a tall card forces a tall
    // row and every short card beside it leaves a hole; packing greedily into
    // the currently-shortest column instead keeps the sheet tight. Heights are
    // estimated from row counts rather than measured — good enough to balance,
    // and it avoids a layout pass that would depend on the result.
    function columnise(list: var, n: int): var {
        const cols = [];
        const heights = [];
        for (let i = 0; i < n; i++) {
            cols.push([]);
            heights.push(0);
        }
        for (const g of list) {
            let best = 0;
            for (let i = 1; i < n; i++)
                if (heights[i] < heights[best])
                    best = i;
            cols[best].push(g);
            // title + rows + card padding, in arbitrary but consistent units.
            heights[best] += 2 + g.rows.length;
        }
        return cols;
    }

    FileView {
        id: bindsFile

        // The deployed config, not the repo copy: this is what Hyprland loaded,
        // so it is what the user's keys actually do.
        path: `${Quickshell.env("HOME")}/.config/hypr/lua/binds.lua`
        watchChanges: true
        onLoaded: root.reload()
        onFileChanged: reload()

        // An unreadable binds.lua is not fatal — the panel still opens and says
        // so, which beats a cheat sheet that silently shows only the hand-written
        // text-editing group as if that were everything.
        onLoadFailed: {
            root.groups = [root.textGroup];
            root.parsed = true;
        }
    }

    IpcHandler {
        target: "keycheat"

        function toggle(): void {
            root.open = !root.open;
        }

        function open(): void {
            root.open = true;
        }

        function close(): void {
            root.open = false;
        }
    }

    PanelWindow {
        id: win

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        visible: root.open || backdrop.opacity > 0.01

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        WlrLayershell.namespace: "qshell:keycheat"
        WlrLayershell.layer: WlrLayer.Overlay
        // OnDemand rather than None (what the GTK version used): the sheet can
        // now be dismissed with Escape like every other panel, instead of only
        // by clicking or re-firing the bind.
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        mask: Region {
            item: root.open ? backdrop : null
        }

        HyprlandFocusGrab {
            active: root.open
            windows: [win]
            onCleared: root.open = false
        }

        Rectangle {
            id: backdrop

            anchors.fill: parent
            color: Qt.alpha(Theme.shadow, 0.42)
            opacity: root.open ? 1 : 0

            Behavior on opacity {
                Anim {
                    duration: Appearance.anim.durations.expressiveSlowEffects
                    curve: Appearance.anim.curves.expressiveSlowEffects
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.open = false
            }

            FocusScope {
                anchors.fill: parent
                focus: true

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        root.open = false;
                        event.accepted = true;
                    }
                }

                Elevation {
                    anchors.fill: panel
                    radius: panel.radius
                    level: 4
                }

                Rectangle {
                    id: panel

                    // Sized to the content but capped against the screen, so a
                    // long config scrolls instead of running off the top and
                    // bottom edges.
                    anchors.centerIn: parent
                    width: Math.min(parent.width - Appearance.s(80), flow.implicitWidth + Appearance.s(44))
                    height: Math.min(parent.height - Appearance.s(80), header.height + flow.implicitHeight + Appearance.s(60))
                    radius: Appearance.s(22)
                    color: Theme.surfaceBg
                    border.width: 1
                    border.color: Theme.surfaceBorder
                    scale: root.open ? 1 : 0.96

                    Behavior on scale {
                        Anim {
                            curve: Appearance.anim.curves.expressiveDefaultSpatial
                            duration: Appearance.anim.durations.expressiveDefaultSpatial
                        }
                    }

                    // Swallow clicks on the card so they don't reach the
                    // backdrop's close handler underneath.
                    MouseArea {
                        anchors.fill: parent
                    }

                    Item {
                        id: header

                        x: Appearance.s(22)
                        y: Appearance.s(18)
                        width: parent.width - Appearance.s(44)
                        height: Appearance.s(30)

                        StyledText {
                            id: title

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Keyboard"
                            color: Theme.surfaceFg
                            font.pixelSize: Appearance.font.size.large
                            font.weight: Font.Bold
                        }

                        StyledText {
                            anchors.left: title.right
                            anchors.leftMargin: Appearance.s(6)
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Shortcuts"
                            color: Theme.accent
                            font.pixelSize: Appearance.font.size.large
                            font.weight: Font.Bold
                        }

                        StyledText {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.parsed ? "Super + /  ·  Esc or click to close" : "reading binds.lua…"
                            color: Theme.surfaceFgDim
                            font.pixelSize: Appearance.font.size.small
                        }
                    }

                    ScrollView {
                        anchors.top: header.bottom
                        anchors.topMargin: Appearance.s(14)
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: Appearance.s(22)
                        anchors.rightMargin: Appearance.s(22)
                        anchors.bottomMargin: Appearance.s(20)
                        clip: true

                        Row {
                            id: flow

                            // Wider than the GTK version's columns: several
                            // labels ("control center pages: (s)ound…") were
                            // eliding at 330.
                            readonly property int cardWidth: Appearance.s(376)
                            readonly property int cols: 4

                            width: flow.cols * cardWidth + (flow.cols - 1) * Appearance.s(12)
                            spacing: Appearance.s(12)

                            Repeater {
                                model: root.columnise(root.groups, flow.cols)

                                Column {
                                    required property var modelData

                                    width: flow.cardWidth
                                    spacing: Appearance.s(12)

                                    Repeater {
                                        model: parent.modelData

                                        Rectangle {
                                            id: card

                                            required property var modelData

                                            width: flow.cardWidth
                                            implicitHeight: cardCol.implicitHeight + Appearance.s(22)
                                            height: implicitHeight
                                            radius: Appearance.s(14)
                                            color: Theme.surfaceHoverBg
                                            border.width: 1
                                            border.color: Qt.alpha(Theme.surfaceBorder, 0.6)

                                            Column {
                                                id: cardCol

                                                x: Appearance.s(12)
                                                y: Appearance.s(11)
                                                width: parent.width - Appearance.s(24)
                                                spacing: Appearance.s(5)

                                                StyledText {
                                                    width: parent.width
                                                    text: root.shortName(card.modelData.name).toUpperCase()
                                                    color: Theme.accent
                                                    font.pixelSize: Appearance.font.size.small
                                                    font.weight: Font.Bold
                                                    font.letterSpacing: 1.6
                                                    bottomPadding: Appearance.s(3)
                                                    elide: Text.ElideRight
                                                }

                                                Repeater {
                                                    model: card.modelData.rows

                                                    Item {
                                                        id: row

                                                        required property var modelData

                                                        width: cardCol.width
                                                        height: Math.max(chips.height, desc.implicitHeight)

                                                        Row {
                                                            id: chips

                                                            anchors.left: parent.left
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            spacing: Appearance.s(3)

                                                            Repeater {
                                                                model: row.modelData.combo.split(" + ")

                                                                Row {
                                                                    id: chipWrap

                                                                    required property var modelData
                                                                    required property int index

                                                                    spacing: Appearance.s(3)

                                                                    StyledText {
                                                                        anchors.verticalCenter: parent.verticalCenter
                                                                        visible: chipWrap.index > 0
                                                                        text: "+"
                                                                        color: Qt.alpha(Theme.surfaceFgDim, 0.7)
                                                                        font.pixelSize: Appearance.font.size.small
                                                                    }

                                                                    Rectangle {
                                                                        readonly property string token: chipWrap.modelData
                                                                        readonly property bool isMod: root.modifierTokens.indexOf(token) >= 0

                                                                        implicitWidth: chipText.implicitWidth + Appearance.s(11)
                                                                        implicitHeight: chipText.implicitHeight + Appearance.s(5)
                                                                        radius: Appearance.rounding.small
                                                                        color: isMod ? Qt.alpha(Theme.accent, 0.16) : Theme.surfaceBg
                                                                        border.width: 1
                                                                        border.color: isMod ? Qt.alpha(Theme.accent, 0.42) : Theme.surfaceBorder

                                                                        StyledText {
                                                                            id: chipText

                                                                            anchors.centerIn: parent
                                                                            text: root.keymap[parent.token] ?? parent.token
                                                                            color: parent.isMod ? Theme.accent : Theme.surfaceFg
                                                                            font.pixelSize: Appearance.font.size.small
                                                                            font.weight: Font.DemiBold
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }

                                                        StyledText {
                                                            id: desc

                                                            anchors.right: parent.right
                                                            anchors.left: chips.right
                                                            anchors.leftMargin: Appearance.s(8)
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            text: row.modelData.label
                                                            color: Theme.surfaceFgDim
                                                            font.pixelSize: Appearance.font.size.small
                                                            horizontalAlignment: Text.AlignRight
                                                            // A handful of labels are full sentences
                                                            // ("control center pages: (s)ound (b)luetooth
                                                            // (k)de connect (d)isplays"). Two lines, then
                                                            // elide — the row grows to fit because its
                                                            // height tracks desc.implicitHeight.
                                                            wrapMode: Text.WordWrap
                                                            maximumLineCount: 2
                                                            elide: Text.ElideRight
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
