import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// One clipboard entry as a card, in the shape macOS Paste uses: who copied it
// across the top, the content itself filling the middle at a size you can
// actually read, and what/when along the bottom. A 56px row could only ever
// show the first line of anything — which is exactly the wrong line when you
// are looking for the *second* URL you copied out of a page.
Item {
    id: root

    required property var modelData
    required property int index

    // The window the picker was opened over, carried down so a click can paste
    // into it. Empty when paste-on-select is off or there was no window.
    property string pasteAddr: ""
    property string pasteClass: ""

    readonly property bool selected: ListView.isCurrentItem

    // Cache file holding the decoded bytes of a binary entry.
    property string thumb: ""
    // Full text of a truncated entry, re-read because cliphist's 100-char
    // preview cuts off exactly what a card has the room to show.
    property string fullText: ""

    readonly property bool isBinary: modelData.image
    // A pinned row is served entirely from its own payload file; nothing here
    // may reach for cliphist on its behalf, because the id it was made from is
    // the first thing to go.
    readonly property bool isPin: modelData.pinned === true

    readonly property string kind: Clipboard.kindOf(modelData)
    readonly property string body: root.fullText || Clipboard.entryText(root.modelData)

    readonly property var paths: fullText ? Clipboard.parsePaths(fullText) : modelData.paths
    readonly property bool isPath: paths.length > 0
    readonly property string firstPath: isPath ? paths[0] : ""
    readonly property bool isImageFile: isPath && Clipboard.isImagePath(firstPath)
    readonly property bool showsThumb: isBinary || isImageFile

    // Who copied it. Pins lose this the moment they stop being a cliphist row,
    // which is honest: a pin is yours now, not the browser's.
    readonly property var source: Clipboard.sourceFor(modelData)
    readonly property var sourceEntry: root.source ? Apps.entryFor(root.source.cls) : null
    // Anything copied before the watcher started recording sources has none;
    // the header says what the card *is* rather than going blank, so the band
    // reads as a header on every card instead of an empty strip on some.
    readonly property string sourceName: {
        if (root.isPin)
            return "Pinned";
        const named = root.sourceEntry?.name || root.source?.cls;
        if (named)
            return named;
        return root.kind === "image" ? "Image" : root.kind === "link" ? "Link" : root.kind === "file" ? "File" : root.kind === "color" ? "Color" : "Text";
    }

    readonly property string thumbSource: {
        if (isImageFile)
            return `file://${firstPath}`;
        if (isPin)
            return isBinary ? `file://${modelData.file}` : "";
        return thumb ? `file://${thumb}` : "";
    }

    // "PNG · 2228×609 · 576 KiB" for bytes, the folder for a path, a line
    // count for text — the thing you'd squint at the content to work out.
    readonly property string meta: {
        if (root.showsThumb || root.isBinary)
            return [modelData.kind, modelData.dims, modelData.size].filter(s => s).join(" · ");
        if (root.isPath)
            return Clipboard.dirName(root.firstPath);
        const lines = root.body.split("\n").length;
        if (lines > 1)
            return `${lines} lines`;
        const chars = root.body.trim().length;
        return `${chars} character${chars === 1 ? "" : "s"}`;
    }

    signal activated
    // Carries the card's index from BEFORE the removal: the model reset snaps
    // currentIndex to 0, and the handler restores the position from this.
    signal removed(int at)

    function drop(): void {
        const at = root.index;
        if (root.isPin)
            Clipboard.unpin(root.modelData);
        else
            Clipboard.remove(root.modelData.id);
        root.removed(at);
    }

    function take(): void {
        Clipboard.copyEntry(root.modelData, root.pasteAddr, root.pasteClass);
        root.activated();
    }

    width: Appearance.sizes.clipCardWidth
    height: Appearance.sizes.clipCardHeight

    // Decode lazily, per delegate: the ListView only builds what is near the
    // viewport, so scrolling to an image is what pays for it, and the file
    // cache means scrolling back is free.
    Process {
        running: root.isBinary && !root.isPin
        command: ["sh", "-c", `d='${Clipboard.thumbDir}'; f="$d/${root.modelData.id}"; mkdir -p "$d"; [ -s "$f" ] || cliphist decode ${root.modelData.id} > "$f" 2>/dev/null; printf %s "$f"`]

        stdout: StdioCollector {
            onStreamFinished: root.thumb = text.trim()
        }
    }

    Process {
        running: !root.isBinary && !root.isPin && root.modelData.truncated
        command: ["cliphist", "decode", root.modelData.id]

        stdout: StdioCollector {
            onStreamFinished: root.fullText = text.trim()
        }
    }

    Elevation {
        anchors.fill: card
        radius: card.radius
        level: root.selected ? 3 : 1
        opacity: card.opacity
    }

    Rectangle {
        id: card

        anchors.fill: parent
        // The selected card stands up off the strip rather than merely
        // changing colour — at this size a border alone reads as decoration.
        anchors.topMargin: root.selected ? 0 : Appearance.s(6)
        anchors.bottomMargin: root.selected ? Appearance.s(6) : 0
        radius: Appearance.s(14)
        color: Theme.surfaceBg
        border.width: root.selected ? 2 : 1
        border.color: root.selected ? Theme.accent : Theme.surfaceBorder

        Behavior on anchors.topMargin {
            Anim {
                duration: Appearance.anim.durations.expressiveFastSpatial
                curve: Appearance.anim.curves.emphasizedDecel
            }
        }

        Behavior on anchors.bottomMargin {
            Anim {
                duration: Appearance.anim.durations.expressiveFastSpatial
                curve: Appearance.anim.curves.emphasizedDecel
            }
        }

        StateLayer {
            id: cardLayer

            radius: card.radius
            color: Theme.surfaceFg
            hoverOpacity: 0.05
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton

            // Hover moves the selection, so there is one highlight and Enter
            // always takes what looks taken. Filtered on window coordinates:
            // Qt re-delivers hover every frame that content slides under a
            // stationary cursor, and honouring those yanks the selection back
            // under the pointer on every keystroke.
            function hoverSelect(): void {
                const view = root.ListView.view;
                if (!view)
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
            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton)
                    root.drop();
                else
                    root.take();
            }
        }

        // ── Header: who it came from ──
        Item {
            id: header

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Appearance.s(8)
            height: Appearance.s(20)

            IconImage {
                id: appIcon

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: Appearance.s(16)
                visible: source !== ""
                asynchronous: true
                source: root.isPin ? "" : ((root.sourceEntry?.icon && Quickshell.iconPath(root.sourceEntry.icon, true)) || "")
            }

            FIcon {
                id: fallbackGlyph

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: !appIcon.visible
                icon: root.isPin ? "pin_fill" : "doc_on_clipboard"
                font.pixelSize: Appearance.s(14)
                color: root.isPin ? Theme.accent : Theme.surfaceFgDim
            }

            StyledText {
                anchors.left: appIcon.visible ? appIcon.right : fallbackGlyph.right
                anchors.leftMargin: Appearance.s(6)
                anchors.right: age.left
                anchors.rightMargin: Appearance.s(4)
                anchors.verticalCenter: parent.verticalCenter
                text: root.sourceName
                color: root.isPin ? Theme.accent : Theme.surfaceFgDim
                font.pixelSize: Appearance.font.size.small
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            StyledText {
                id: age

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Clipboard.ageOf(root.modelData)
                color: Theme.surfaceFgDim
                font.pixelSize: Appearance.font.size.small
                font.weight: Font.Normal
            }
        }

        // ── Body: the content, at a size worth reading ──
        ClippingRectangle {
            id: bodyArea

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.bottom: footer.top
            anchors.leftMargin: Appearance.s(8)
            anchors.rightMargin: Appearance.s(8)
            anchors.topMargin: Appearance.s(6)
            anchors.bottomMargin: Appearance.s(6)
            radius: Appearance.s(8)
            color: root.showsThumb ? Qt.alpha(Theme.surfaceFg, 0.06) : "transparent"

            Image {
                id: thumbImage

                anchors.fill: parent
                visible: root.showsThumb
                source: root.thumbSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                sourceSize.width: Appearance.s(420)
            }

            // Covers the decode gap, a missing file, and formats Qt can't read.
            FIcon {
                anchors.centerIn: parent
                visible: root.showsThumb && thumbImage.status !== Image.Ready
                icon: "photo"
                font.pixelSize: Appearance.s(22)
                color: Theme.surfaceFgDim
            }

            // A colour is the one payload whose *value* is what it looks like.
            Rectangle {
                anchors.fill: parent
                visible: root.kind === "color"
                // bodyArea by id, not `parent`: a ClippingRectangle reparents
                // its children into a plain content item, which has no radius.
                radius: bodyArea.radius
                color: visible ? Clipboard.colorOf(root.modelData) : "transparent"
                border.width: 1
                border.color: Qt.alpha(Theme.surfaceFg, 0.15)
            }

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                visible: root.isPath && !root.showsThumb
                spacing: Appearance.s(2)

                FIcon {
                    icon: "doc_text"
                    font.pixelSize: Appearance.s(22)
                    color: Theme.surfaceFgDim
                }

                StyledText {
                    width: parent.width
                    text: root.isPath ? Clipboard.baseName(root.firstPath) : ""
                    color: Theme.surfaceFg
                    font.pixelSize: Appearance.font.size.small
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    visible: root.paths.length > 1
                    text: `+${root.paths.length - 1} more`
                    color: Theme.surfaceFgDim
                    font.pixelSize: Appearance.font.size.small
                    font.weight: Font.Normal
                }
            }

            // Text and links. Left-aligned and top-anchored like the page it
            // came from, not centred like a label.
            StyledText {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                visible: !root.showsThumb && !root.isPath && root.kind !== "color"
                text: root.body
                color: root.kind === "link" ? Theme.accent : Theme.surfaceFg
                font.pixelSize: Appearance.font.size.small
                font.weight: Font.Normal
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                // Whatever fits, cut on a line rather than mid-glyph.
                maximumLineCount: Math.max(1, Math.floor(bodyArea.height / (Appearance.font.size.small * 1.45)))
                elide: Text.ElideRight
                lineHeight: 1.25
            }
        }

        // ── Footer: what it is ──
        Item {
            id: footer

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Appearance.s(8)
            height: Appearance.s(16)

            StyledText {
                anchors.left: parent.left
                anchors.right: pinBtn.left
                anchors.rightMargin: Appearance.s(4)
                anchors.verticalCenter: parent.verticalCenter
                text: root.meta
                color: Theme.surfaceFgDim
                font.pixelSize: Appearance.font.size.small
                font.weight: Font.Normal
                elide: Text.ElideMiddle
            }

            // Pin and delete live on the selected card only: six cards each
            // showing two buttons is a wall of chrome over the content the
            // cards exist to show.
            Row {
                id: pinBtn

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.s(2)
                visible: root.selected || cardLayer.containsMouse

                Item {
                    width: Appearance.s(18)
                    height: Appearance.s(18)

                    StateLayer {
                        radius: width / 2
                        color: Theme.surfaceFg
                        onClicked: Clipboard.togglePin(root.modelData)
                    }

                    FIcon {
                        anchors.centerIn: parent
                        icon: root.isPin ? "pin_slash" : "pin"
                        font.pixelSize: Appearance.s(13)
                        color: root.isPin ? Theme.accent : Theme.surfaceFgDim
                    }
                }

                Item {
                    width: Appearance.s(18)
                    height: Appearance.s(18)

                    StateLayer {
                        radius: width / 2
                        color: Theme.urgent
                        onClicked: root.drop()
                    }

                    FIcon {
                        anchors.centerIn: parent
                        icon: "xmark"
                        font.pixelSize: Appearance.s(13)
                        color: Theme.surfaceFgDim
                    }
                }
            }
        }
    }
}
