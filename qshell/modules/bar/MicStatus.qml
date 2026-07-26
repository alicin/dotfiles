import QtQuick
import qs.config
import qs.components
import qs.services

// Muted-mic indicator. Only exists while the mic is actually muted — the
// interesting state is the one where you're talking and nobody can hear you,
// and a permanently-lit mic icon would make exactly that state easy to miss.
//
// Click unmutes, which also makes this disappear; the OSD is asked for
// explicitly, since the module vanishing is otherwise the only confirmation
// and it's a poor one.
Item {
    id: root

    visible: Audio.micMuted
    implicitWidth: visible ? glyph.implicitWidth + Appearance.sizes.modulePad : 0
    implicitHeight: Appearance.sizes.barInner

    StateLayer {
        onClicked: {
            Audio.toggleMicMute();
            Osd.show("mic");
        }
    }

    FIcon {
        id: glyph

        anchors.centerIn: parent
        icon: "mic_slash_fill"
        color: Theme.barWarn
    }
}
