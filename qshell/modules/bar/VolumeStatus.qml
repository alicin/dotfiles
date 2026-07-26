import QtQuick
import qs.config
import qs.components
import qs.services

// Output volume glyph; click opens the mixer, scroll adjusts volume.
Item {
    id: root

    property var popouts: null

    implicitWidth: glyph.implicitWidth + Appearance.sizes.modulePad
    implicitHeight: Appearance.sizes.barInner

    StateLayer {
        onClicked: root.popouts?.toggle("audio", root)
    }

    WheelHandler {
        onWheel: event => Audio.setVolume(Audio.volume + (event.angleDelta.y > 0 ? 0.04 : -0.04))
    }

    FIcon {
        id: glyph

        anchors.centerIn: parent
        icon: Audio.muted ? "speaker_slash_fill" : Audio.volume < 0.34 ? "speaker_1_fill" : Audio.volume < 0.67 ? "speaker_2_fill" : "speaker_3_fill"
        color: Audio.muted ? Theme.barFgDim : Theme.barFg
    }
}
