import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.config
import qs.components
import qs.services

// Control Center home. Everything here is either a one-tap toggle or a slider —
// anything that needs a list (sound devices, Bluetooth pairing, KDE Connect
// actions) gets a row that drills into its own page, so the common case is
// always reachable without leaving this screen.
Column {
    id: root

    signal navigate(string page)

    readonly property real tileW: (width - Appearance.s(8)) / 2

    // Filtered: a player that fails to register (bad MPRIS implementation)
    // can leave a null in the model, and every binding below would throw on it.
    readonly property var players: [...Mpris.players.values].filter(p => p)

    readonly property BluetoothAdapter btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: btAdapter?.enabled ?? false
    readonly property var btConnected: [...Bluetooth.devices.values].filter(d => d.connected)

    // One phone is the interesting case; the page lists the rest.
    readonly property var phone: KdeConnect.reachable[0] ?? KdeConnect.devices[0] ?? null

    function btSubtitle(): string {
        if (!root.btOn)
            return "Off";
        if (root.btConnected.length === 0)
            return "On";
        if (root.btConnected.length === 1)
            return root.btConnected[0].name || root.btConnected[0].address;
        return `${root.btConnected.length} devices`;
    }

    function phoneSubtitle(): string {
        const d = root.phone;
        if (!d)
            return "No paired devices";
        if (!d.reachable)
            return "Not reachable";
        const bits = [];
        if (d.battery >= 0)
            bits.push(`${d.battery}%${d.charging ? " charging" : ""}`);
        if (d.network)
            bits.push(d.network);
        return bits.length ? bits.join(" · ") : "Connected";
    }

    spacing: Appearance.s(8)

    // Brightness is read by polling brightnessctl, and KDE Connect's daemon
    // poll is slow enough to look stale — both are only worth doing while this
    // is actually on screen.
    Component.onCompleted: {
        Brightness.polling = true;
        KdeConnect.refresh();
        // One shot, not the page's poll: the Displays tile shows a count in its
        // subtitle and would otherwise read "…" until you opened the page it
        // is the shortcut to.
        Displays.refresh();
    }
    Component.onDestruction: Brightness.polling = false

    // Two-up toggle tile: badge, title, state line.
    component Tile: Rectangle {
        id: tile

        property string fIcon: ""
        property string title: ""
        property string subtitle: ""
        property bool active: false

        signal tapped

        width: root.tileW
        height: Appearance.s(60)
        radius: Appearance.s(14)
        color: Theme.surfaceHoverBg

        StateLayer {
            radius: tile.radius
            color: Theme.surfaceFg
            onClicked: tile.tapped()
        }

        Badge {
            id: tileBadge

            x: Appearance.s(10)
            anchors.verticalCenter: parent.verticalCenter
            glyph: tile.fIcon
            active: tile.active
        }

        Column {
            anchors.left: tileBadge.right
            anchors.leftMargin: Appearance.s(8)
            anchors.right: parent.right
            anchors.rightMargin: Appearance.s(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            StyledText {
                width: parent.width
                text: tile.title
                color: Theme.surfaceFg
                font.pixelSize: Appearance.font.size.small
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                text: tile.subtitle
                color: Theme.surfaceFgDim
                font.pixelSize: Appearance.font.size.small
                font.weight: Font.Normal
                elide: Text.ElideRight
            }
        }
    }

    // Trailing "there's more behind this" affordance. A real button, not just
    // a glyph — it's the only way into a page from a row that also has its own
    // controls.
    component Disclosure: Item {
        id: disc

        signal tapped

        width: Appearance.s(26)
        height: Appearance.s(30)

        StateLayer {
            radius: Appearance.s(8)
            color: Theme.surfaceFg
            onClicked: disc.tapped()
        }

        FIcon {
            anchors.centerIn: parent
            icon: "chevron_right"
            font.pixelSize: Appearance.font.size.small
            color: Theme.surfaceFgDim
        }
    }

    // ── Connectivity ──
    // Split hit targets, macOS-style: the badge toggles the radio, the rest of
    // the row opens the page. Both get their own hover wash so which-does-what
    // is visible before you commit to a click.
    Card {
        Item {
            width: parent.width
            height: Appearance.s(48)

            StateLayer {
                radius: Appearance.s(10)
                color: Theme.surfaceFg
                onClicked: root.navigate("bluetooth")
            }

            Badge {
                id: btBadge

                x: Appearance.s(8)
                anchors.verticalCenter: parent.verticalCenter
                // Framework7 has no bluetooth glyph at all — nerd runes here.
                rune: !root.btOn ? "󰂲" : root.btConnected.length > 0 ? "󰂱" : "󰂯"
                active: root.btOn
                toggles: true
                onTapped: {
                    if (root.btAdapter)
                        root.btAdapter.enabled = !root.btOn;
                }
            }

            Column {
                anchors.left: btBadge.right
                anchors.leftMargin: Appearance.s(10)
                anchors.right: btChevron.left
                anchors.rightMargin: Appearance.s(6)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                StyledText {
                    width: parent.width
                    text: "Bluetooth"
                    color: Theme.surfaceFg
                    font.pixelSize: Appearance.font.size.small
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    text: root.btSubtitle()
                    color: root.btConnected.length > 0 ? Theme.ok : Theme.surfaceFgDim
                    font.pixelSize: Appearance.font.size.small
                    font.weight: Font.Normal
                    elide: Text.ElideRight
                }
            }

            FIcon {
                id: btChevron

                anchors.right: parent.right
                anchors.rightMargin: Appearance.s(12)
                anchors.verticalCenter: parent.verticalCenter
                icon: "chevron_right"
                font.pixelSize: Appearance.font.size.small
                color: Theme.surfaceFgDim
            }
        }

        MenuSeparator {
            x: Appearance.s(52)
            width: parent.width - Appearance.s(64)
        }

        Item {
            width: parent.width
            height: Appearance.s(48)

            StateLayer {
                radius: Appearance.s(10)
                color: Theme.surfaceFg
                onClicked: root.navigate("kdeconnect")
            }

            Badge {
                id: phoneBadge

                x: Appearance.s(8)
                anchors.verticalCenter: parent.verticalCenter
                glyph: "device_phone_portrait"
                active: (root.phone?.reachable ?? false)
            }

            Column {
                anchors.left: phoneBadge.right
                anchors.leftMargin: Appearance.s(10)
                anchors.right: phoneChevron.left
                anchors.rightMargin: Appearance.s(6)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                StyledText {
                    width: parent.width
                    text: root.phone?.name ?? "KDE Connect"
                    color: Theme.surfaceFg
                    font.pixelSize: Appearance.font.size.small
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    text: root.phoneSubtitle()
                    color: (root.phone?.reachable ?? false) ? Theme.ok : Theme.surfaceFgDim
                    font.pixelSize: Appearance.font.size.small
                    font.weight: Font.Normal
                    elide: Text.ElideRight
                }
            }

            FIcon {
                id: phoneChevron

                anchors.right: parent.right
                anchors.rightMargin: Appearance.s(12)
                anchors.verticalCenter: parent.verticalCenter
                icon: "chevron_right"
                font.pixelSize: Appearance.font.size.small
                color: Theme.surfaceFgDim
            }
        }
    }

    // ── Focus / caffeine / night light ──
    // Three tiles in two columns: the third wraps onto its own row, which is
    // what the Flow is for. A third *column* would put every label at half its
    // current width, and "Do Not Disturb" is already the tightest one here.
    Flow {
        width: parent.width
        spacing: Appearance.s(8)

        Tile {
            fIcon: "moon_fill"
            title: "Do Not Disturb"
            subtitle: Notifs.dnd ? "On" : "Off"
            active: Notifs.dnd
            onTapped: Notifs.toggleDnd()
        }

        Tile {
            fIcon: Idle.inhibited ? "eye_fill" : "moon_zzz_fill"
            title: "Keep Awake"
            // Says so when a recording is what's holding it, rather than
            // reading "Off" while the machine demonstrably won't sleep.
            subtitle: Idle.inhibited ? "On" : Idle.active ? "Recording" : "Off"
            active: Idle.active
            onTapped: Idle.toggle()
        }

        Tile {
            fIcon: "sun_haze_fill"
            title: "Night Light"
            // "Install hyprsunset" elides to "Install hyprsuns…" in a
            // half-width tile, which reads like a truncated error.
            subtitle: !NightLight.available ? "Not installed" : NightLight.enabled ? `${NightLight.temperature}K` : "Off"
            active: NightLight.enabled && NightLight.available
            onTapped: {
                if (NightLight.available)
                    NightLight.toggle();
            }
        }

        Tile {
            fIcon: "device_desktop"
            title: "Displays"
            subtitle: Displays.summary
            active: false
            onTapped: root.navigate("display")
        }
    }

    // ── Sound ──
    // Master volume stays on home so the common case never needs the page; the
    // chevron is for picking devices and per-app levels.
    Card {
        Item {
            width: parent.width
            height: Appearance.s(32)

            Item {
                id: muteBtn

                x: Appearance.s(6)
                width: Appearance.s(30)
                height: parent.height

                StateLayer {
                    radius: Appearance.s(9)
                    color: Theme.surfaceFg
                    onClicked: Audio.toggleMute()
                }

                FIcon {
                    anchors.centerIn: parent
                    icon: Audio.muted ? "speaker_slash_fill" : Audio.volume < 0.34 ? "speaker_1_fill" : Audio.volume < 0.67 ? "speaker_2_fill" : "speaker_3_fill"
                    color: Audio.muted ? Theme.surfaceFgDim : Theme.surfaceFg
                }
            }

            StyledSlider {
                anchors.left: muteBtn.right
                anchors.leftMargin: Appearance.s(6)
                anchors.right: volChevron.left
                anchors.rightMargin: Appearance.s(8)
                anchors.verticalCenter: parent.verticalCenter
                value: Audio.volume
                onMoved: value => Audio.setVolume(value)
            }

            Disclosure {
                id: volChevron

                anchors.right: parent.right
                anchors.rightMargin: Appearance.s(6)
                anchors.verticalCenter: parent.verticalCenter
                onTapped: root.navigate("audio")
            }
        }

        StyledText {
            x: Appearance.s(42)
            width: parent.width - Appearance.s(56)
            text: `${Audio.sink?.description || "No output"} · ${Math.round(Audio.volume * 100)}%`
            color: Theme.surfaceFgDim
            font.pixelSize: Appearance.font.size.small
            font.weight: Font.Normal
            elide: Text.ElideRight
        }
    }

    // ── Display brightness ──
    Rectangle {
        width: parent.width
        height: Appearance.s(52)
        radius: Appearance.s(14)
        color: Theme.surfaceHoverBg

        FIcon {
            id: brightGlyph

            x: Appearance.s(12)
            anchors.verticalCenter: parent.verticalCenter
            icon: "sun_max_fill"
            color: Theme.surfaceFg
        }

        StyledSlider {
            anchors.left: brightGlyph.right
            anchors.leftMargin: Appearance.s(12)
            anchors.right: brightPct.left
            anchors.rightMargin: Appearance.s(8)
            anchors.verticalCenter: parent.verticalCenter
            value: Brightness.display
            onMoved: value => Brightness.setDisplay(value)
        }

        // Same readout the volume card and Sound page sliders carry — this
        // was the odd one out with no visible setpoint.
        StyledText {
            id: brightPct

            anchors.right: parent.right
            anchors.rightMargin: Appearance.s(12)
            anchors.verticalCenter: parent.verticalCenter
            width: Appearance.s(36)
            horizontalAlignment: Text.AlignRight
            text: `${Math.round(Brightness.display * 100)}%`
            color: Theme.surfaceFgDim
            font.pixelSize: Appearance.font.size.small
        }
    }

    // ── Keyboard backlight ──
    Rectangle {
        visible: Brightness.kbdAvailable
        width: parent.width
        height: Appearance.s(46)
        radius: Appearance.s(14)
        color: Theme.surfaceHoverBg

        StateLayer {
            radius: parent.radius
            color: Theme.surfaceFg
            onClicked: Brightness.cycleKbd()
        }

        FIcon {
            id: kbdGlyph

            x: Appearance.s(12)
            anchors.verticalCenter: parent.verticalCenter
            icon: "keyboard"
            color: Brightness.kbd > 0 ? Theme.accent : Theme.surfaceFgDim
        }

        StyledText {
            anchors.left: kbdGlyph.right
            anchors.leftMargin: Appearance.s(12)
            anchors.verticalCenter: parent.verticalCenter
            text: "Keyboard"
            color: Theme.surfaceFg
            font.pixelSize: Appearance.font.size.small
        }

        // Level pips rather than a slider — the ROG backlight has exactly
        // three steps plus off, and tapping cycles through them.
        Row {
            anchors.right: parent.right
            anchors.rightMargin: Appearance.s(14)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.s(5)

            Repeater {
                model: Brightness.kbdMax

                Rectangle {
                    required property int index

                    width: Appearance.s(8)
                    height: width
                    radius: width / 2
                    color: index < Brightness.kbd ? Theme.accent : Qt.alpha(Theme.surfaceFg, 0.2)

                    Behavior on color {
                        CAnim {}
                    }
                }
            }
        }
    }

    // ── Media ──
    Rectangle {
        visible: root.players.length > 0
        width: parent.width
        height: Appearance.s(84)
        radius: Appearance.s(14)
        color: Theme.surfaceHoverBg

        // One page per player, snapping horizontally — flick sideways when
        // more than one thing is playing.
        ListView {
            id: mediaList

            anchors.fill: parent
            anchors.bottomMargin: root.players.length > 1 ? Appearance.s(10) : 0
            orientation: ListView.Horizontal
            snapMode: ListView.SnapOneItem
            highlightRangeMode: ListView.StrictlyEnforceRange
            boundsBehavior: Flickable.StopAtBounds
            interactive: root.players.length > 1
            clip: true

            model: ScriptModel {
                values: root.players
            }

            delegate: Item {
                id: page

                required property var modelData

                // Untyped on purpose: declaring this `MprisPlayer` makes the
                // coercion from ScriptModel's modelData fail silently to null,
                // and every binding below then throws.
                readonly property var player: modelData

                width: mediaList.width
                height: mediaList.height

                // Click the art or title to raise the player window — every
                // other daily-driver shell does this, and pause-only cards
                // make you go hunt the window yourself. Behind the content,
                // stops at the transport controls.
                Item {
                    anchors.left: parent.left
                    anchors.right: controls.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    StateLayer {
                        radius: Appearance.s(10)
                        color: Theme.surfaceFg
                        enabled: page.player?.canRaise ?? false
                        onClicked: page.player?.raise()
                    }
                }

                ClippingRectangle {
                    id: artBox

                    x: Appearance.s(10)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Appearance.s(52)
                    height: width
                    radius: Appearance.s(8)
                    color: Qt.alpha(Theme.surfaceFg, 0.1)

                    Image {
                        id: art

                        anchors.fill: parent
                        source: page.player?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: Appearance.s(104)
                    }

                    // Players without art, and the gap while it loads.
                    FIcon {
                        anchors.centerIn: parent
                        visible: art.status !== Image.Ready
                        icon: "music_note_2"
                        font.pixelSize: Appearance.s(20)
                        color: Theme.surfaceFgDim
                    }
                }

                Column {
                    anchors.left: artBox.right
                    anchors.leftMargin: Appearance.s(10)
                    anchors.right: controls.left
                    anchors.rightMargin: Appearance.s(8)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.s(2)

                    StyledText {
                        width: parent.width
                        text: page.player?.trackTitle || page.player?.identity || "Unknown"
                        color: Theme.surfaceFg
                        font.pixelSize: Appearance.font.size.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        width: parent.width
                        visible: text !== ""
                        text: page.player?.trackArtist ?? ""
                        color: Theme.surfaceFgDim
                        font.pixelSize: Appearance.font.size.small
                        font.weight: Font.Normal
                        elide: Text.ElideRight
                    }
                }

                Row {
                    id: controls

                    anchors.right: parent.right
                    anchors.rightMargin: Appearance.s(8)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    component CtlButton: Item {
                        id: ctl

                        property string glyph: ""
                        property bool enabled: true

                        signal tapped

                        width: Appearance.s(30)
                        height: Appearance.s(30)
                        opacity: enabled ? 1 : 0.35

                        StateLayer {
                            radius: width / 2
                            color: Theme.surfaceFg
                            enabled: ctl.enabled
                            onClicked: ctl.tapped()
                        }

                        FIcon {
                            anchors.centerIn: parent
                            icon: ctl.glyph
                            font.pixelSize: Appearance.s(15)
                            color: Theme.surfaceFg
                        }
                    }

                    CtlButton {
                        glyph: "backward_fill"
                        enabled: page.player?.canGoPrevious ?? false
                        onTapped: page.player?.previous()
                    }

                    CtlButton {
                        glyph: (page.player?.isPlaying ?? false) ? "pause_fill" : "play_fill"
                        enabled: page.player?.canTogglePlaying ?? false
                        onTapped: page.player?.togglePlaying()
                    }

                    CtlButton {
                        glyph: "forward_fill"
                        enabled: page.player?.canGoNext ?? false
                        onTapped: page.player?.next()
                    }
                }

                // Track position, ticked once a second while the card is on
                // screen (the comma dependency forces the re-read — position
                // itself doesn't notify continuously).
                Rectangle {
                    visible: (page.player?.length ?? 0) > 0 && (page.player?.positionSupported ?? false)
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Appearance.s(10)
                    anchors.rightMargin: Appearance.s(10)
                    anchors.bottom: parent.bottom
                    height: Math.max(2, Appearance.s(2))
                    radius: height / 2
                    color: Qt.alpha(Theme.surfaceFg, 0.15)

                    Rectangle {
                        width: parent.width * (posTick.tick, Math.max(0, Math.min(1, (page.player?.position ?? 0) / Math.max(1, page.player?.length ?? 1))))
                        height: parent.height
                        radius: parent.radius
                        color: Theme.accent
                    }
                }
            }
        }

        Timer {
            id: posTick

            property int tick: 0

            running: root.players.length > 0
            interval: 1000
            repeat: true
            onTriggered: tick++
        }

        // Page dots, only when there's more than one player to page between.
        Row {
            visible: root.players.length > 1
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Appearance.s(6)
            spacing: Appearance.s(4)

            Repeater {
                model: root.players.length

                Rectangle {
                    required property int index

                    width: Appearance.s(5)
                    height: width
                    radius: width / 2
                    color: index === mediaList.currentIndex ? Theme.accent : Qt.alpha(Theme.surfaceFg, 0.25)

                    Behavior on color {
                        CAnim {}
                    }
                }
            }
        }
    }

    // ── Capture ──
    // Mode is an explicit choice rather than a single button with a hidden
    // default: area / window / whole screen read differently enough that
    // guessing wrong costs a retake.
    Rectangle {
        id: capCard

        width: parent.width
        // Derived, not a constant: a fixed height was ~10px short once the
        // record row was added, and the buttons spilled onto the card below.
        // recRow's anchor chain never reads parent.height, so this can't loop.
        height: recRow.y + recRow.height + Appearance.s(7)
        radius: Appearance.s(14)
        color: Theme.surfaceHoverBg

        component CaptureBtn: Item {
            id: cap

            property string glyph: ""
            property string label: ""
            property bool danger: false

            signal tapped

            height: Appearance.s(50)

            StateLayer {
                radius: Appearance.s(10)
                color: cap.danger ? Theme.urgent : Theme.surfaceFg
                onClicked: cap.tapped()
            }

            Column {
                anchors.centerIn: parent
                spacing: Appearance.s(3)

                FIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    icon: cap.glyph
                    font.pixelSize: Appearance.s(16)
                    color: cap.danger ? Theme.urgent : Theme.surfaceFg
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: cap.label
                    color: cap.danger ? Theme.urgent : Theme.surfaceFgDim
                    font.pixelSize: Appearance.font.size.small
                }
            }
        }

        readonly property bool live: Capture.recording || Capture.paused

        StyledText {
            id: capTitle

            x: Appearance.s(12)
            y: Appearance.s(7)
            text: "Screenshot"
            color: Theme.surfaceFgDim
            font.pixelSize: Appearance.font.size.small
        }

        Row {
            id: capRow

            readonly property real cellW: width / 3

            anchors.left: parent.left
            anchors.leftMargin: Appearance.s(8)
            anchors.right: parent.right
            anchors.rightMargin: Appearance.s(8)
            anchors.top: capTitle.bottom
            anchors.topMargin: Appearance.s(2)
            spacing: 0

            CaptureBtn {
                width: capRow.cellW
                glyph: "crop"
                label: "Area"
                onTapped: Capture.shoot("area")
            }

            CaptureBtn {
                width: capRow.cellW
                glyph: "macwindow"
                label: "Window"
                onTapped: Capture.shoot("window")
            }

            CaptureBtn {
                width: capRow.cellW
                glyph: "desktopcomputer"
                label: "Screen"
                onTapped: Capture.shoot("full")
            }
        }

        // Recording gets its own labelled row rather than one cell shared with
        // the screenshots: whole-screen recording was fully implemented and
        // had no caller anywhere, and there was no room to add one to a row of
        // five. While a take is live the row becomes its transport, which is
        // the only thing worth having there.
        StyledText {
            id: recTitle

            x: Appearance.s(12)
            anchors.top: capRow.bottom
            anchors.topMargin: Appearance.s(4)
            text: Capture.paused ? `Paused · ${Capture.elapsedText}` : Capture.recording ? `Recording · ${Capture.elapsedText}` : "Record"
            color: Capture.recording ? Theme.urgent : Capture.paused ? Theme.warn : Theme.surfaceFgDim
            font.pixelSize: Appearance.font.size.small
        }

        Row {
            id: recRow

            readonly property real cellW: width / 3

            anchors.left: parent.left
            anchors.leftMargin: Appearance.s(8)
            anchors.right: parent.right
            anchors.rightMargin: Appearance.s(8)
            anchors.top: recTitle.bottom
            anchors.topMargin: Appearance.s(2)
            spacing: 0

            CaptureBtn {
                width: recRow.cellW
                glyph: capCard.live ? "stop_fill" : "videocam_fill"
                label: capCard.live ? "Stop" : "Area"
                danger: capCard.live
                onTapped: {
                    if (Capture.recording || Capture.paused)
                        Capture.stopRecording();
                    else
                        Capture.recordArea();
                }
            }

            CaptureBtn {
                width: recRow.cellW
                glyph: capCard.live ? (Capture.paused ? "play_fill" : "pause_fill") : "desktopcomputer"
                label: capCard.live ? (Capture.paused ? "Resume" : "Pause") : "Screen"
                onTapped: {
                    if (Capture.recording || Capture.paused)
                        Capture.togglePause();
                    else
                        Capture.recordFull();
                }
            }

            CaptureBtn {
                width: recRow.cellW
                glyph: "eyedropper_halffull"
                label: "Color"
                // Through Capture, not a bare exec: the open panel's focus
                // grab used to eat hyprpicker's first click.
                onTapped: Capture.pickColor()
            }
        }
    }

    // ── Theme ──
    Rectangle {
        width: parent.width
        height: Appearance.s(46)
        radius: Appearance.s(14)
        color: Theme.surfaceHoverBg

        FIcon {
            id: themeGlyph

            x: Appearance.s(12)
            anchors.verticalCenter: parent.verticalCenter
            icon: Settings.theme.includes("latte") ? "sun_max_fill" : "moon_fill"
            color: Theme.accent
        }

        Row {
            anchors.left: themeGlyph.right
            anchors.leftMargin: Appearance.s(10)
            anchors.right: parent.right
            anchors.rightMargin: Appearance.s(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.s(6)

            Repeater {
                model: Theme.available

                Rectangle {
                    id: themeChip

                    required property var modelData

                    readonly property bool active: Settings.theme === modelData

                    width: (parent.width - Appearance.s(6)) / Math.max(1, Theme.available.length)
                    height: Appearance.s(28)
                    radius: Appearance.s(9)
                    color: active ? Theme.accent : Qt.alpha(Theme.surfaceFg, 0.1)

                    Behavior on color {
                        CAnim {}
                    }

                    StateLayer {
                        radius: themeChip.radius
                        color: themeChip.active ? Theme.accentFg : Theme.surfaceFg
                        onClicked: Settings.setTheme(themeChip.modelData)
                    }

                    StyledText {
                        anchors.centerIn: parent
                        // "catppuccin-latte" → "Latte"; the family name is the
                        // same for every entry and just eats the chip.
                        text: {
                            const s = themeChip.modelData.split("-").pop();
                            return s.charAt(0).toUpperCase() + s.slice(1);
                        }
                        color: themeChip.active ? Theme.accentFg : Theme.surfaceFg
                        font.pixelSize: Appearance.font.size.small
                    }
                }
            }
        }
    }

    // ── Session ──
    Row {
        id: sessionRow

        // One armed button at a time, owned by the row: per-button state let
        // two "Sure?" pills sit live at once, and a stale armed poweroff
        // would fire on a single click for up to 2.5s.
        property Item armedBtn: null

        spacing: Appearance.s(8)

        Timer {
            id: disarmTimer

            interval: 2500
            onTriggered: sessionRow.armedBtn = null
        }

        component PowerButton: Rectangle {
            id: pw

            property string glyph: ""
            property bool danger: false
            // Destructive verbs arm on the first tap — the button turns into
            // a labelled "Sure?" that auto-reverts — and fire on the second.
            // One stray click on an icon-only pill used to power the machine
            // off with no undo.
            property bool confirm: false

            readonly property bool armed: sessionRow.armedBtn === pw

            signal tapped

            width: (root.width - Appearance.s(32)) / 5
            height: Appearance.s(46)
            radius: Appearance.s(14)
            color: pw.armed ? Qt.alpha(Theme.urgent, 0.16) : Theme.surfaceHoverBg

            Behavior on color {
                CAnim {}
            }

            StateLayer {
                radius: pw.radius
                color: pw.danger || pw.armed ? Theme.urgent : Theme.surfaceFg
                onClicked: {
                    if (!pw.confirm || pw.armed) {
                        sessionRow.armedBtn = null;
                        disarmTimer.stop();
                        pw.tapped();
                    } else {
                        sessionRow.armedBtn = pw;
                        disarmTimer.restart();
                    }
                }
            }

            FIcon {
                visible: !pw.armed
                anchors.centerIn: parent
                icon: pw.glyph
                font.pixelSize: Appearance.s(17)
                color: pw.danger ? Theme.urgent : Theme.surfaceFg
            }

            StyledText {
                visible: pw.armed
                anchors.centerIn: parent
                text: "Sure?"
                color: Theme.urgent
                font.pixelSize: Appearance.font.size.small
                font.weight: Font.Bold
            }
        }

        // Lock leads: it's the most common session action and used to be
        // reachable only through the Super+Shift+E submap.
        PowerButton {
            glyph: "lock_fill"
            onTapped: Quickshell.execDetached(["loginctl", "lock-session"])
        }

        PowerButton {
            glyph: "power"
            danger: true
            confirm: true
            onTapped: Quickshell.execDetached(["systemctl", "poweroff"])
        }

        PowerButton {
            glyph: "arrow_2_circlepath"
            confirm: true
            onTapped: Quickshell.execDetached(["systemctl", "reboot"])
        }

        // Suspend stays one-tap: it's the only fully reversible verb here.
        PowerButton {
            glyph: "moon_zzz_fill"
            onTapped: Quickshell.execDetached(["systemctl", "suspend"])
        }

        PowerButton {
            glyph: "square_arrow_right"
            confirm: true
            // The hyprland-lua config routes dispatches through `hl.dsp.*`;
            // plain `exit` isn't valid lua there.
            onTapped: Hyprland.dispatch(Hyprland.usingLua ? "hl.dsp.exit()" : "exit")
        }
    }
}
