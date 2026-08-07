import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// One launcher row, whatever it happens to be — an app, a window, a command,
// an emoji, a sum. The sources have nothing in common but a name and a verb
// (see services/Search.qml), so the leading slot is the only part that varies:
// an icon for the things that have one, a glyph for the things that don't, and
// the character itself for emoji.
Item {
    id: root

    required property var modelData
    required property int index

    // The active search text, for match highlighting. The mode prefix is
    // stripped by the launcher — highlighting a "/" that isn't in the name
    // would mark nothing and look broken.
    property string query: ""

    // Set by the launcher on the row it is asking about: a destructive verb
    // wants a second Enter, and says so where you are already looking.
    property bool arming: false

    // Rows that only explain something (the key hints in help) take no verb.
    // `undefined`, not falsy: the help row that walks you back to plain app
    // search carries switchTo: "", which read as "no verb" and rendered it
    // dimmed and unclickable while Enter on it worked fine.
    readonly property bool inert: !modelData.run && modelData.switchTo === undefined

    signal activated

    width: ListView.view ? ListView.view.width : 0
    height: Appearance.sizes.launcherItemHeight

    StateLayer {
        radius: Appearance.s(16)
        color: Theme.surfaceFg
        enabled: !root.inert
        // No private wash: hover moves the list's selection instead, so there
        // is exactly one highlight and Enter always launches what looks
        // active — hover and keyboard used to disagree.
        hoverOpacity: 0
        // Selection follows *real* pointer motion only, filtered on window
        // coordinates: Qt re-delivers hover every frame that content slides
        // under a stationary cursor (keyboard scroll, result churn, the
        // height animation), and honoring those yanked the selection back to
        // the hovered row on every keystroke. The first report after open
        // only calibrates, so the panel rising through a parked cursor can't
        // steal the selection either.
        function hoverSelect(): void {
            // Touch has no hover: the synthesized events are a finger
            // scrolling the list, and following them yanked the selection to
            // whatever row the finger crossed. A tap still activates its own
            // row via onClicked, and OSK Enter uses the keyboard selection —
            // neither needs hover. The dragging/moving guard covers a finger
            // scroll on a docked (pointer-mode) touchscreen the same way.
            if (Appearance.touch)
                return;
            const view = root.ListView.view;
            if (!view || view.dragging || view.moving)
                return;
            const p = mapToItem(null, mouseX, mouseY);
            const first = view.lastHoverPos.x < -1e8;
            if (!first && p.x === view.lastHoverPos.x && p.y === view.lastHoverPos.y)
                return;
            view.lastHoverPos = Qt.point(p.x, p.y);
            if (!first)
                view.currentIndex = root.index;
        }

        onContainsMouseChanged: {
            if (containsMouse)
                hoverSelect();
        }
        onPositionChanged: hoverSelect()
        onClicked: root.activated()
    }

    // ── Leading slot ──

    IconImage {
        id: icon

        anchors.left: parent.left
        anchors.leftMargin: Appearance.s(10)
        anchors.verticalCenter: parent.verticalCenter
        implicitSize: Appearance.s(38)
        visible: (root.modelData.icon ?? "") !== ""
        asynchronous: true
        source: root.modelData.icon ?? ""
    }

    // Emoji are drawn at the size they are being picked at — a 14px preview
    // of the thing you are choosing between is not a preview.
    StyledText {
        id: emojiGlyph

        anchors.horizontalCenter: icon.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        visible: (root.modelData.char ?? "") !== ""
        text: root.modelData.char ?? ""
        // StyledText defaults to Theme.barFg — bar chrome, near-white in every
        // theme — and this one is drawn on a *panel*. Colour-emoji ignore
        // Text.color so they survived it, but the ~168 text-presentation ones
        // (‼ ⁉ ™ ℹ ↔ ⌨ …) are glyphs like any other and went white-on-white on
        // all five light themes.
        color: Theme.surfaceFg
        font.pixelSize: Appearance.s(26)
    }

    // A theme, painted in itself. Sixteen names in a list say nothing about
    // which one you want, and the entire subject is what things look like — so
    // the row shows that theme's own panel colour with its own accent, ok and
    // urgent on it. Reads as a swatch card rather than one more glyph.
    Rectangle {
        id: swatch

        readonly property var palette: Theme.themes[root.modelData.swatch ?? ""] ?? null

        anchors.horizontalCenter: icon.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        visible: palette !== null
        implicitWidth: Appearance.s(38)
        implicitHeight: Appearance.s(38)
        width: implicitWidth
        height: implicitHeight
        radius: Appearance.s(11)
        // The alpha these carry is meant for a panel floating over a
        // wallpaper; here it would composite against the launcher behind it
        // and show every theme as a tint of the current one.
        color: palette ? Qt.rgba(Qt.color(palette.surfaceBg).r, Qt.color(palette.surfaceBg).g, Qt.color(palette.surfaceBg).b, 1) : "transparent"
        border.width: 1
        border.color: palette ? Qt.alpha(Qt.color(palette.surfaceFg), 0.25) : "transparent"

        Row {
            anchors.centerIn: parent
            spacing: Appearance.s(3)

            Repeater {
                model: swatch.palette ? [swatch.palette.accent, swatch.palette.ok, swatch.palette.urgent] : []

                Rectangle {
                    required property var modelData

                    width: Appearance.s(7)
                    height: width
                    radius: width / 2
                    color: modelData
                }
            }
        }
    }

    FIcon {
        id: glyph

        anchors.horizontalCenter: icon.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        visible: !icon.visible && !emojiGlyph.visible && !swatch.visible
        icon: root.modelData.glyph ?? "app_badge"
        font.pixelSize: Appearance.s(22)
        color: root.arming ? Theme.urgent : Theme.surfaceFgDim
    }

    // ── Trailing hint ──
    //
    // What Enter will do, for the rows where that isn't obvious ("Copy" on an
    // emoji, "⇧⏎ terminal" on a command line). Sized before the label so the
    // text elides against it instead of running underneath.
    // Theme rows derive "Active" HERE, reactively, instead of carrying it in
    // the row object: baked-in active-ness changed two rows' identity on
    // every pick, and the model churn threw the selection to the bottom of
    // the picker (see Search.themeRows).
    readonly property string liveBadge: root.modelData.kind === "theme" && root.modelData.swatch === Settings.theme ? "Active" : (root.modelData.badge ?? "")

    StyledText {
        id: badge

        anchors.right: parent.right
        anchors.rightMargin: Appearance.s(14)
        anchors.verticalCenter: parent.verticalCenter
        visible: text !== ""
        text: root.arming ? "Enter again" : root.liveBadge
        color: root.arming ? Theme.urgent : Theme.surfaceFgDim
        font.pixelSize: Appearance.font.size.small
        font.weight: root.arming ? Font.Bold : Font.Normal
    }

    Column {
        anchors.left: icon.left
        anchors.leftMargin: Appearance.s(48)
        anchors.right: badge.visible ? badge.left : parent.right
        anchors.rightMargin: Appearance.s(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        StyledText {
            width: parent.width
            textFormat: Text.StyledText
            text: Apps.markMatches(root.modelData.name ?? "", root.query)
            color: root.inert ? Theme.surfaceFgDim : Theme.surfaceFg
            elide: Text.ElideRight
        }

        StyledText {
            width: parent.width
            visible: text.length > 0
            text: root.modelData.sub ?? ""
            color: Theme.surfaceFgDim
            font.pixelSize: Appearance.font.size.small
            font.weight: Font.Normal
            elide: Text.ElideRight
        }
    }
}
