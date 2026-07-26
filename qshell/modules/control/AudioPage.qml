import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.config
import qs.components
import qs.services

// Sound page: output level + device picker, input level + device picker, and a
// per-app mixer. This was its own bar dropdown; the master slider now lives on
// the Control Center home screen, so this page is only ever needed for the
// things that genuinely take a list.
Column {
    id: root

    signal back

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && ((n.properties["media.class"] ?? "") + "").startsWith("Audio/Source") && !n.name.endsWith(".monitor"))
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && (n.properties["media.class"] ?? "") === "Stream/Output/Audio")

    readonly property PwNode source: Pipewire.defaultAudioSource

    // Rows past this scroll instead of growing the panel past the screen.
    readonly property int maxRows: 4
    readonly property int rowH: Appearance.s(32)

    function streamName(n: var): string {
        return (n.properties["application.name"] ?? "") || n.description || n.name;
    }

    spacing: Appearance.s(8)

    // Track everything while the page is open — node properties (media.class)
    // only populate for tracked nodes, and every filter above needs them.
    PwObjectTracker {
        objects: [...Pipewire.nodes.values]
    }

    // Glyph (mutes) + slider + percentage.
    component LevelRow: Item {
        id: lvl

        property string glyph: ""
        property bool muted: false
        property real level: 0

        signal moved(real value)
        signal muteToggled

        width: parent.width
        height: Appearance.s(34)

        Item {
            id: lvlBtn

            x: Appearance.s(6)
            width: Appearance.s(30)
            height: parent.height

            StateLayer {
                radius: Appearance.s(9)
                color: Theme.surfaceFg
                onClicked: lvl.muteToggled()
            }

            FIcon {
                anchors.centerIn: parent
                icon: lvl.glyph
                color: lvl.muted ? Theme.surfaceFgDim : Theme.surfaceFg
            }
        }

        StyledSlider {
            anchors.left: lvlBtn.right
            anchors.leftMargin: Appearance.s(6)
            anchors.right: lvlPct.left
            anchors.rightMargin: Appearance.s(8)
            anchors.verticalCenter: parent.verticalCenter
            value: lvl.level
            onMoved: v => lvl.moved(v)
        }

        StyledText {
            id: lvlPct

            anchors.right: parent.right
            anchors.rightMargin: Appearance.s(10)
            anchors.verticalCenter: parent.verticalCenter
            width: Appearance.s(36)
            horizontalAlignment: Text.AlignRight
            text: `${Math.round(lvl.level * 100)}%`
            color: Theme.surfaceFgDim
            font.pixelSize: Appearance.font.size.small
        }
    }

    // A selectable device in the output/input pickers.
    component PickRow: Item {
        id: pick

        required property var node
        property bool current: false

        signal chosen

        width: ListView.view ? ListView.view.width : parent.width
        height: root.rowH

        StateLayer {
            radius: Appearance.rounding.normal
            color: Theme.surfaceFg
            onClicked: pick.chosen()
        }

        StyledText {
            anchors.left: parent.left
            anchors.leftMargin: Appearance.s(12)
            anchors.right: pickCheck.left
            anchors.rightMargin: Appearance.s(8)
            anchors.verticalCenter: parent.verticalCenter
            text: pick.node.description || pick.node.name
            color: pick.current ? Theme.accent : Theme.surfaceFg
            font.pixelSize: Appearance.font.size.small
            font.weight: pick.current ? Font.Medium : Font.Normal
            elide: Text.ElideRight
        }

        FIcon {
            id: pickCheck

            anchors.right: parent.right
            anchors.rightMargin: Appearance.s(12)
            anchors.verticalCenter: parent.verticalCenter
            visible: pick.current
            icon: "checkmark_alt"
            font.pixelSize: Appearance.font.size.small
            color: Theme.accent
        }
    }

    PageHeader {
        title: "Sound"
        onBack: root.back()
    }

    // ── Output ──
    Card {
        title: "Output"

        LevelRow {
            glyph: Audio.muted ? "speaker_slash_fill" : "speaker_3_fill"
            muted: Audio.muted
            level: Audio.volume
            onMoved: v => Audio.setVolume(v)
            onMuteToggled: Audio.toggleMute()
        }

        ListView {
            id: sinkList

            width: parent.width
            height: Math.min(contentHeight, root.maxRows * root.rowH)
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            WheelScroll {
                view: sinkList
            }

            model: ScriptModel {
                values: root.sinks
            }

            delegate: PickRow {
                required property var modelData

                node: modelData
                current: Pipewire.defaultAudioSink?.id === modelData.id
                onChosen: Pipewire.preferredDefaultAudioSink = modelData
            }
        }
    }

    // ── Input ──
    Card {
        title: "Input"

        // Through the Audio service rather than the node directly, so these
        // count as the shell's own edits and don't summon an OSD over the
        // slider you're already holding.
        LevelRow {
            glyph: Audio.micMuted ? "mic_slash_fill" : "mic_fill"
            muted: Audio.micMuted
            level: Audio.micVolume
            onMoved: v => Audio.setMicVolume(v)
            onMuteToggled: Audio.toggleMicMute()
        }

        ListView {
            id: sourceList

            width: parent.width
            height: Math.min(contentHeight, root.maxRows * root.rowH)
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            WheelScroll {
                view: sourceList
            }

            model: ScriptModel {
                values: root.sources
            }

            delegate: PickRow {
                required property var modelData

                node: modelData
                current: Pipewire.defaultAudioSource?.id === modelData.id
                onChosen: Pipewire.preferredDefaultAudioSource = modelData
            }
        }
    }

    // ── Per-app ──
    Card {
        title: "Apps"

        StyledText {
            x: Appearance.s(12)
            visible: root.streams.length === 0
            height: visible ? Appearance.s(28) : 0
            text: "Nothing playing"
            color: Theme.surfaceFgDim
            font.pixelSize: Appearance.font.size.small
            font.weight: Font.Normal
        }

        ListView {
            id: streamList

            width: parent.width
            height: Math.min(contentHeight, root.maxRows * Appearance.s(44))
            visible: root.streams.length > 0
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            WheelScroll {
                view: streamList
            }

            model: ScriptModel {
                values: root.streams
            }

            delegate: Item {
                id: streamItem

                required property var modelData

                width: streamList.width
                height: Appearance.s(44)

                StyledText {
                    x: Appearance.s(12)
                    y: 0
                    width: parent.width - Appearance.s(70)
                    text: root.streamName(streamItem.modelData)
                    color: Theme.surfaceFg
                    font.pixelSize: Appearance.font.size.small
                    elide: Text.ElideRight
                }

                StyledSlider {
                    anchors.left: parent.left
                    anchors.leftMargin: Appearance.s(12)
                    anchors.right: streamPct.left
                    anchors.rightMargin: Appearance.s(8)
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
                    anchors.rightMargin: Appearance.s(10)
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Appearance.s(6)
                    width: Appearance.s(36)
                    horizontalAlignment: Text.AlignRight
                    text: `${Math.round((streamItem.modelData.audio?.volume ?? 0) * 100)}%`
                    color: Theme.surfaceFgDim
                    font.pixelSize: Appearance.font.size.small
                }
            }
        }
    }
}
