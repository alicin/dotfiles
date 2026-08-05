import QtQuick
import Quickshell.Services.Mpris
import qs.config
import qs.components
import qs.services

// Now playing, left of the privacy lights. The Control Center already has a
// full media card, but pausing through it is two clicks and a panel — this is
// the one-click version, which is what a menubar is for.
//
// Only appears while something is actually playing or paused; a permanent
// "nothing is playing" slot would just be dead width.
Item {
    id: root

    property var popouts: null
    property var tooltip: null

    // Filtered like the Control Center's card: a player that fails to register
    // leaves a null in the model and every binding below would throw on it.
    readonly property var players: [...Mpris.players.values].filter(p => p)

    // Whatever is playing wins; otherwise the first paused player, so hitting
    // play resumes what you last stopped rather than nothing at all.
    readonly property var player: root.players.find(p => p.isPlaying) ?? root.players[0] ?? null

    readonly property bool playing: root.player?.isPlaying ?? false
    readonly property string title: root.player?.trackTitle || root.player?.identity || ""
    readonly property string artist: root.player?.trackArtist ?? ""

    visible: root.player !== null && root.title !== ""
    implicitWidth: visible ? content.implicitWidth + Appearance.sizes.modulePad : 0
    implicitHeight: Appearance.sizes.barInner

    StateLayer {
        hitSlop: Appearance.sizes.barSlop
        // Middle click raises the player window — the same verb the Control
        // Center card's body has, for when "what is this?" beats "pause it".
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton)
                root.player?.raise();
            else if (root.player?.canTogglePlaying ?? false)
                root.player.togglePlaying();
        }
        onContainsMouseChanged: {
            if (containsMouse)
                root.tooltip?.show(root.artist ? `${root.title} — ${root.artist}` : root.title, root);
            else
                root.tooltip?.hide(root);
        }
    }

    // Vertical slop only, via the wrapper: a handler `margin` extends every
    // side and would steal scrolls made over the neighbouring module.
    Item {
        anchors.fill: parent
        anchors.topMargin: -Appearance.sizes.barSlop
        anchors.bottomMargin: -Appearance.sizes.barSlop

        WheelDetent {
            // Whole notches only: skipping tracks is discrete, and a touchpad
            // flick that fires `moved` per event would jump five songs.
            onStepped: steps => {
                const p = root.player;
                if (!p)
                    return;
                if (steps < 0) {
                    if (p.canGoNext)
                        p.next();
                } else if (p.canGoPrevious) {
                    p.previous();
                }
            }
        }
    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: Appearance.s(5)

        FIcon {
            anchors.verticalCenter: parent.verticalCenter
            icon: root.playing ? "pause_fill" : "play_fill"
            font.pixelSize: Appearance.s(13)
            color: root.playing ? Theme.barFg : Theme.barFgDim
        }

        // Capped: a podcast episode title is longer than the whole bar, and
        // the tooltip carries the full text anyway.
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, Appearance.s(170))
            text: root.title
            color: root.playing ? Theme.barFg : Theme.barFgDim
            elide: Text.ElideRight
        }
    }
}
