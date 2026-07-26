import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.config
import qs.components
import qs.services

// Master volume, per-app streams, output/input device pickers.
Column {
    id: root

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && ((n.properties["media.class"] ?? "") + "").startsWith("Audio/Source") && !n.name.endsWith(".monitor"))
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && (n.properties["media.class"] ?? "") === "Stream/Output/Audio")

    readonly property PwNode source: Pipewire.defaultAudioSource

    function streamName(n: var): string {
        return (n.properties["application.name"] ?? "") || n.description || n.name;
    }

    width: Appearance.s(380)
    spacing: Appearance.s(2)

    // Track everything while the menu is open — node properties (media.class)
    // only populate for tracked nodes, and the display filters need them.
    PwObjectTracker {
        objects: [...Pipewire.nodes.values]
    }

    // ── Master ──
    Item {
        width: parent.width
        height: Appearance.sizes.menuRowHeight

        FIcon {
            id: masterGlyph

            x: Appearance.s(8)
            anchors.verticalCenter: parent.verticalCenter
            icon: Audio.muted ? "speaker_slash_fill" : "speaker_3_fill"
            color: Audio.muted ? Theme.surfaceFgDim : Theme.surfaceFg

            StateLayer {
                radius: Appearance.rounding.small
                color: Theme.surfaceFg
                onClicked: Audio.toggleMute()
            }
        }

        StyledSlider {
            anchors.left: masterGlyph.right
            anchors.leftMargin: Appearance.s(12)
            anchors.right: masterPct.left
            anchors.rightMargin: Appearance.s(10)
            anchors.verticalCenter: parent.verticalCenter
            value: Audio.volume
            onMoved: value => Audio.setVolume(value)
        }

        StyledText {
            id: masterPct

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Appearance.s(38)
            horizontalAlignment: Text.AlignRight
            text: `${Math.round(Audio.volume * 100)}%`
            color: Theme.surfaceFgDim
            font.pixelSize: Appearance.font.size.small
        }
    }

    // ── App streams ──
    MenuSeparator {
        width: parent.width
    }

    StyledText {
        height: Appearance.s(26)
        text: "Apps"
        color: Theme.surfaceFgDim
        font.pixelSize: Appearance.font.size.small
    }

    StyledText {
        visible: root.streams.length === 0
        height: Appearance.s(30)
        text: "Nothing playing"
        color: Theme.surfaceFgDim
    }

    Repeater {
        model: ScriptModel {
            values: root.streams
        }

        Item {
            id: streamItem

            required property var modelData

            width: parent.width
            height: Appearance.s(46)

            StyledText {
                id: streamLabel

                x: Appearance.s(8)
                y: 0
                width: parent.width - Appearance.s(60)
                text: root.streamName(streamItem.modelData)
                color: Theme.surfaceFg
                font.pixelSize: Appearance.font.size.small
                elide: Text.ElideRight
            }

            StyledSlider {
                anchors.left: parent.left
                anchors.leftMargin: Appearance.s(8)
                anchors.right: streamPct.left
                anchors.rightMargin: Appearance.s(10)
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Appearance.s(2)
                value: streamItem.modelData.audio?.volume ?? 0
                onMoved: value => {
                    if (streamItem.modelData.audio)
                        streamItem.modelData.audio.volume = value;
                }
            }

            StyledText {
                id: streamPct

                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Appearance.s(6)
                width: Appearance.s(38)
                horizontalAlignment: Text.AlignRight
                text: `${Math.round((streamItem.modelData.audio?.volume ?? 0) * 100)}%`
                color: Theme.surfaceFgDim
                font.pixelSize: Appearance.font.size.small
            }
        }
    }

    // ── Output devices ──
    MenuSeparator {
        width: parent.width
    }

    StyledText {
        height: Appearance.s(26)
        text: "Output"
        color: Theme.surfaceFgDim
        font.pixelSize: Appearance.font.size.small
    }

    Repeater {
        model: ScriptModel {
            values: root.sinks
        }

        Item {
            id: sinkItem

            required property var modelData

            readonly property bool isDefault: Pipewire.defaultAudioSink?.id === modelData.id

            width: parent.width
            height: Appearance.s(34)

            StateLayer {
                radius: Appearance.rounding.normal
                color: Theme.surfaceFg
                onClicked: Pipewire.preferredDefaultAudioSink = sinkItem.modelData
            }

            StyledText {
                anchors.left: parent.left
                anchors.leftMargin: Appearance.s(8)
                anchors.right: sinkCheck.left
                anchors.rightMargin: Appearance.s(8)
                anchors.verticalCenter: parent.verticalCenter
                text: sinkItem.modelData.description || sinkItem.modelData.name
                color: Theme.surfaceFg
                font.pixelSize: Appearance.font.size.small
                elide: Text.ElideRight
            }

            FIcon {
                id: sinkCheck

                anchors.right: parent.right
                anchors.rightMargin: Appearance.s(10)
                anchors.verticalCenter: parent.verticalCenter
                visible: sinkItem.isDefault
                icon: "checkmark_alt"
                color: Theme.accent
            }
        }
    }

    // ── Input ──
    MenuSeparator {
        width: parent.width
    }

    StyledText {
        height: Appearance.s(26)
        text: "Input"
        color: Theme.surfaceFgDim
        font.pixelSize: Appearance.font.size.small
    }

    Item {
        width: parent.width
        height: Appearance.sizes.menuRowHeight

        FIcon {
            id: micGlyph

            x: Appearance.s(8)
            anchors.verticalCenter: parent.verticalCenter
            icon: (root.source?.audio?.muted ?? false) ? "mic_slash_fill" : "mic_fill"
            color: (root.source?.audio?.muted ?? false) ? Theme.surfaceFgDim : Theme.surfaceFg

            StateLayer {
                radius: Appearance.rounding.small
                color: Theme.surfaceFg
                onClicked: {
                    if (root.source?.audio)
                        root.source.audio.muted = !root.source.audio.muted;
                }
            }
        }

        StyledSlider {
            anchors.left: micGlyph.right
            anchors.leftMargin: Appearance.s(12)
            anchors.right: micPct.left
            anchors.rightMargin: Appearance.s(10)
            anchors.verticalCenter: parent.verticalCenter
            value: root.source?.audio?.volume ?? 0
            onMoved: value => {
                if (root.source?.audio)
                    root.source.audio.volume = value;
            }
        }

        StyledText {
            id: micPct

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Appearance.s(38)
            horizontalAlignment: Text.AlignRight
            text: `${Math.round((root.source?.audio?.volume ?? 0) * 100)}%`
            color: Theme.surfaceFgDim
            font.pixelSize: Appearance.font.size.small
        }
    }

    Repeater {
        model: ScriptModel {
            values: root.sources
        }

        Item {
            id: sourceItem

            required property var modelData

            readonly property bool isDefault: Pipewire.defaultAudioSource?.id === modelData.id

            width: parent.width
            height: Appearance.s(34)

            StateLayer {
                radius: Appearance.rounding.normal
                color: Theme.surfaceFg
                onClicked: Pipewire.preferredDefaultAudioSource = sourceItem.modelData
            }

            StyledText {
                anchors.left: parent.left
                anchors.leftMargin: Appearance.s(8)
                anchors.right: sourceCheck.left
                anchors.rightMargin: Appearance.s(8)
                anchors.verticalCenter: parent.verticalCenter
                text: sourceItem.modelData.description || sourceItem.modelData.name
                color: Theme.surfaceFg
                font.pixelSize: Appearance.font.size.small
                elide: Text.ElideRight
            }

            FIcon {
                id: sourceCheck

                anchors.right: parent.right
                anchors.rightMargin: Appearance.s(10)
                anchors.verticalCenter: parent.verticalCenter
                visible: sourceItem.isDefault
                icon: "checkmark_alt"
                color: Theme.accent
            }
        }
    }
}
