import QtQuick
import Quickshell.Io
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property var modelData

    // Cache file holding the decoded bytes of a binary entry.
    property string thumb: ""
    // Full text of a truncated path entry, re-read because cliphist's 100-char
    // preview cuts off exactly the part we want to show — the filename.
    property string fullText: ""

    readonly property bool isBinary: modelData.image

    readonly property var paths: fullText ? Clipboard.parsePaths(fullText) : modelData.paths
    readonly property bool isPath: paths.length > 0
    readonly property string firstPath: isPath ? paths[0] : ""
    readonly property bool isImageFile: isPath && Clipboard.isImagePath(firstPath)

    // Filename for a copied path, "Image" for pasted bytes, else the text.
    readonly property string label: {
        if (isPath) {
            const name = Clipboard.baseName(firstPath);
            return paths.length > 1 ? `${name}  +${paths.length - 1} more` : name;
        }
        return isBinary ? "Image" : modelData.preview;
    }

    // "PNG · 2228×609 · 576 KiB" for bytes, the containing folder for a path.
    readonly property string details: isPath ? Clipboard.dirName(firstPath) : [modelData.kind, modelData.dims, modelData.size].filter(s => s).join(" · ")

    readonly property bool showsThumb: isBinary || isImageFile

    // Image files are read straight off disk; pasted bytes have to be decoded
    // out of cliphist first. A path that no longer exists just fails to load
    // and falls back to the glyph.
    readonly property string thumbSource: {
        if (isImageFile)
            return `file://${firstPath}`;
        return thumb ? `file://${thumb}` : "";
    }

    signal activated
    signal removed

    width: ListView.view ? ListView.view.width : 0
    height: Appearance.sizes.launcherItemHeight

    // Decode lazily, per delegate: ListView only builds what's near the
    // viewport, so scrolling to an image is what pays for it, and the file
    // cache means scrolling back is free.
    Process {
        running: root.isBinary
        command: ["sh", "-c", `d='${Clipboard.thumbDir}'; f="$d/${root.modelData.id}"; mkdir -p "$d"; [ -s "$f" ] || cliphist decode ${root.modelData.id} > "$f" 2>/dev/null; printf %s "$f"`]

        stdout: StdioCollector {
            onStreamFinished: root.thumb = text.trim()
        }
    }

    Process {
        running: !root.isBinary && root.modelData.truncated
        command: ["cliphist", "decode", root.modelData.id]

        stdout: StdioCollector {
            onStreamFinished: root.fullText = text.trim()
        }
    }

    StateLayer {
        radius: Appearance.s(16)
        color: Theme.surfaceFg
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                Clipboard.remove(root.modelData.id);
                root.removed();
            } else {
                Clipboard.copy(root.modelData.id);
                root.activated();
            }
        }
    }

    // ── Leading: thumbnail where there's an image, glyph otherwise ──
    Item {
        id: lead

        anchors.left: parent.left
        anchors.leftMargin: Appearance.s(12)
        anchors.verticalCenter: parent.verticalCenter
        width: Appearance.s(58)
        height: Appearance.s(36)

        FIcon {
            anchors.centerIn: parent
            visible: !root.showsThumb
            icon: root.isPath ? "doc_text" : "doc_on_clipboard"
            font.pixelSize: Appearance.s(20)
            color: Theme.surfaceFgDim
        }

        ClippingRectangle {
            anchors.fill: parent
            visible: root.showsThumb
            radius: Appearance.s(6)
            color: Qt.alpha(Theme.surfaceFg, 0.08)

            Image {
                id: thumbImage

                anchors.fill: parent
                source: root.thumbSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                // Screenshots run to a few thousand pixels wide; decoding them
                // at full size for a 58px row is pure waste.
                sourceSize.width: Appearance.s(116)
            }

            // Covers the decode gap, a missing file, and formats Qt can't read.
            FIcon {
                anchors.centerIn: parent
                visible: thumbImage.status !== Image.Ready
                icon: "photo"
                font.pixelSize: Appearance.s(18)
                color: Theme.surfaceFgDim
            }
        }
    }

    Column {
        anchors.left: lead.right
        anchors.leftMargin: Appearance.s(12)
        anchors.right: parent.right
        anchors.rightMargin: Appearance.s(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        StyledText {
            width: parent.width
            text: root.label
            color: Theme.surfaceFg
            elide: Text.ElideRight
        }

        // Plain text gets no second line — it would just be the same string
        // truncated differently.
        StyledText {
            width: parent.width
            visible: (root.isBinary || root.isPath) && text !== ""
            text: root.details
            color: Theme.surfaceFgDim
            font.pixelSize: Appearance.font.size.small
            font.weight: Font.Normal
            elide: Text.ElideMiddle
        }
    }
}
