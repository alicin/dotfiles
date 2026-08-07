import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// Settings, in its own window — macOS System Settings shaped: a sidebar of
// sections with colored icon chips on the left, one section's controls on the
// right. It replaced the Control Center's settings drill-down page (per ali):
// a panel page had one width, one column and no room, and settings are the
// thing you leave open beside whatever you are adjusting them for.
//
// A FloatingWindow, not a layer surface: Hyprland floats org.quickshell
// toplevels natively, it gets a real border and Super+Q, and the launcher's
// theme picker can open over it. State lives in services/SettingsUi.qml so
// the Control Center gear and `qs -c qshell ipc call settings open` share it.
//
// The row components below came verbatim from the old SettingsPage.qml —
// their comments (why sliders get their own line, why steppers not sliders,
// why fields commit on Return/blur only) still apply and travel with them.
Scope {
    id: root

    // Trailing zeros off. The sliders step by 0.05, 0.1 and 0.25, so any
    // fixed precision is wrong for two of them.
    function num(v: real): string {
        return `${Math.round(v * 100) / 100}`;
    }

    readonly property var sections: [
        {
            key: "appearance",
            label: "Appearance",
            icon: "paintbrush_fill",
            tint: "#0a84ff"
        },
        {
            key: "desktop",
            label: "Desktop",
            icon: "rectangle_grid_2x2_fill",
            tint: "#5e5ce6"
        },
        {
            key: "tablet",
            label: "Tablet & Touch",
            icon: "hand_draw",
            tint: "#ff9f0a"
        },
        {
            key: "keyboard",
            label: "On-screen Keyboard",
            icon: "keyboard",
            tint: "#af52de"
        },
        {
            key: "weather",
            label: "Weather",
            icon: "cloud_sun_fill",
            tint: "#32ade6"
        },
        {
            key: "clipboard",
            label: "Clipboard",
            icon: "doc_on_clipboard_fill",
            tint: "#34c759"
        },
        {
            key: "system",
            label: "System",
            icon: "gear_alt_fill",
            tint: "#8e8e93"
        }
    ]

    readonly property string sectionLabel: root.sections.find(s => s.key === SettingsUi.section)?.label ?? "Settings"

    // ── Row shapes (from SettingsPage.qml, unchanged) ──

    // Label and value on one line, track on its own line underneath — sharing
    // a line costs the track too many pixels for the fine-stepped sliders.
    component SliderRow: Item {
        id: sl

        property string label: ""
        property string readout: ""
        property real from: 0
        property real to: 1
        property real step: 0.05
        property real value: 0

        signal moved(real value)

        width: parent.width
        height: Appearance.s(48)

        StyledText {
            id: slLabel

            x: Appearance.s(12)
            y: Appearance.s(4)
            width: parent.width - Appearance.s(24) - slValue.width
            text: sl.label
            color: Theme.surfaceFg
            font.pixelSize: Appearance.font.size.small
            elide: Text.ElideRight
        }

        StyledText {
            id: slValue

            anchors.right: parent.right
            anchors.rightMargin: Appearance.s(12)
            y: slLabel.y
            text: sl.readout
            color: Theme.surfaceFgDim
            font.pixelSize: Appearance.font.size.small
            font.weight: Font.Normal
        }

        StyledSlider {
            anchors.left: parent.left
            anchors.leftMargin: Appearance.s(12)
            anchors.right: parent.right
            anchors.rightMargin: Appearance.s(12)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Appearance.s(5)
            value: (sl.value - sl.from) / (sl.to - sl.from)
            onMoved: t => {
                // Snapped here rather than in the setter so the knob lands
                // where the readout claims it did.
                const raw = sl.from + t * (sl.to - sl.from);
                sl.moved(Math.round(raw / sl.step) * sl.step);
            }
        }
    }

    // One end of a stepper. `armed` rather than the inherited `enabled`: an
    // Item's `enabled` propagates and would freeze the StateLayer wash too.
    component StepBtn: Item {
        id: btn

        property string glyph: ""
        property bool armed: true

        signal tapped

        // The full touch floor: an undersized ± that misses low lands on the
        // neighbouring stepper's button and silently changes the wrong count.
        width: Math.max(Appearance.s(26), Appearance.touchTarget)
        height: Math.max(Appearance.s(26), Appearance.touchTarget)
        opacity: btn.armed ? 1 : 0.3

        StateLayer {
            radius: Appearance.s(8)
            color: Theme.surfaceFg
            enabled: btn.armed
            onClicked: btn.tapped()
        }

        FIcon {
            anchors.centerIn: parent
            icon: btn.glyph
            font.pixelSize: Appearance.font.size.small
            color: Theme.surfaceFg
        }
    }

    // Small integers get −/+ rather than a slider: these are settings you
    // arrive at already knowing the answer to.
    component StepperRow: Item {
        id: st

        property string label: ""
        property int from: 1
        property int to: 20
        property int value: 0

        signal stepped(int value)

        width: parent.width
        height: Math.max(Appearance.s(34), Appearance.touchTarget)

        StyledText {
            anchors.left: parent.left
            anchors.leftMargin: Appearance.s(12)
            anchors.right: stBox.left
            anchors.rightMargin: Appearance.s(8)
            anchors.verticalCenter: parent.verticalCenter
            text: st.label
            color: Theme.surfaceFg
            font.pixelSize: Appearance.font.size.small
            elide: Text.ElideRight
        }

        Row {
            id: stBox

            anchors.right: parent.right
            anchors.rightMargin: Appearance.s(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.s(2)

            StepBtn {
                anchors.verticalCenter: parent.verticalCenter
                glyph: "minus"
                armed: st.value > st.from
                onTapped: st.stepped(st.value - 1)
            }

            // Fixed width so the −/+ pair doesn't shuffle sideways when the
            // count crosses from one digit to two.
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: Appearance.s(26)
                horizontalAlignment: Text.AlignHCenter
                text: `${st.value}`
                color: Theme.surfaceFg
                font.pixelSize: Appearance.font.size.small
            }

            StepBtn {
                anchors.verticalCenter: parent.verticalCenter
                glyph: "plus"
                armed: st.value < st.to
                onTapped: st.stepped(st.value + 1)
            }
        }
    }

    // A short, closed set of answers, laid out as a segmented pill.
    component ChoiceRow: Item {
        id: ch

        property string label: ""
        // [{ value, label }] — `value` is what goes to the setter.
        property var options: []
        property string value: ""

        signal picked(string value)

        width: parent.width
        height: Math.max(Appearance.s(38), Appearance.touchTarget)

        StyledText {
            anchors.left: parent.left
            anchors.leftMargin: Appearance.s(12)
            anchors.right: chSeg.left
            anchors.rightMargin: Appearance.s(8)
            anchors.verticalCenter: parent.verticalCenter
            text: ch.label
            color: Theme.surfaceFg
            font.pixelSize: Appearance.font.size.small
            elide: Text.ElideRight
        }

        Row {
            id: chSeg

            anchors.right: parent.right
            anchors.rightMargin: Appearance.s(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.s(3)

            Repeater {
                model: ch.options

                Rectangle {
                    id: chSegment

                    required property var modelData

                    readonly property bool on: chSegment.modelData.value === ch.value

                    implicitWidth: chLabel.implicitWidth + Appearance.s(18)
                    // Full touch floor, not 0.75 of it — the segments are the
                    // hit targets, and the row is already floored to match.
                    implicitHeight: Math.max(Appearance.s(26), Appearance.touchTarget)
                    radius: height / 2
                    color: chSegment.on ? Theme.accent : Qt.alpha(Theme.surfaceFg, 0.1)

                    Behavior on color {
                        CAnim {}
                    }

                    StateLayer {
                        radius: chSegment.radius
                        color: chSegment.on ? Theme.accentFg : Theme.surfaceFg
                        onClicked: ch.picked(chSegment.modelData.value)
                    }

                    StyledText {
                        id: chLabel

                        anchors.centerIn: parent
                        text: chSegment.modelData.label
                        color: chSegment.on ? Theme.accentFg : Theme.surfaceFg
                        font.pixelSize: Appearance.font.size.small
                    }
                }
            }
        }
    }

    component SwitchRow: Item {
        id: sw

        property string label: ""
        property bool checked: false

        signal switched(bool checked)

        width: parent.width
        height: Math.max(Appearance.s(34), Appearance.touchTarget)

        // The whole row toggles, not just the switch at its far end.
        StateLayer {
            radius: Appearance.s(8)
            color: Theme.surfaceFg
            onClicked: sw.switched(!sw.checked)
        }

        StyledText {
            anchors.left: parent.left
            anchors.leftMargin: Appearance.s(12)
            anchors.right: swCtl.left
            anchors.rightMargin: Appearance.s(10)
            anchors.verticalCenter: parent.verticalCenter
            text: sw.label
            color: Theme.surfaceFg
            font.pixelSize: Appearance.font.size.small
            elide: Text.ElideRight
        }

        StyledSwitch {
            id: swCtl

            anchors.right: parent.right
            anchors.rightMargin: Appearance.s(8)
            anchors.verticalCenter: parent.verticalCenter
            checked: sw.checked
            onToggled: next => sw.switched(next)
        }
    }

    // Label on the left, pill field on the right. Committed on Return or on
    // losing focus, never per keystroke — `terminal` is read straight into an
    // execDetached, and a launcher `!` fired mid-retype would spawn "kit".
    component TextRow: Item {
        id: tf

        property string label: ""
        property string placeholder: ""
        property string value: ""
        property bool armed: true
        // What a committed value must look like. "" accepts anything.
        property string pattern: ""
        // Drop interior whitespace too — for one-token values people space
        // out by habit ("37.7749, -122.4194"). Off for `terminal`: stripping
        // would turn "kitty --hold" into the single token "kitty--hold".
        property bool strip: false
        // The value is itself a regex, so it must compile before it stores.
        property bool mustCompile: false

        signal committed(string text)

        // Programmatic writes park the caret at the head so a long value
        // renders from its identifying start, not its tail.
        function show(t: string): void {
            input.text = t;
            input.cursorPosition = 0;
        }

        function revert(): void {
            tf.show(tf.value);
        }

        function accepts(t: string): bool {
            if (tf.pattern !== "" && !new RegExp(tf.pattern).test(t))
                return false;
            if (tf.mustCompile) {
                try {
                    new RegExp(t);
                } catch (e) {
                    return false;
                }
            }
            return true;
        }

        function commit(): void {
            const t = tf.strip ? input.text.replace(/\s+/g, "") : input.text.trim();
            if (t === tf.value) {
                tf.show(t);
                return;
            }
            if (!tf.accepts(t)) {
                // The red beat is the only error channel a row this size has.
                tf.revert();
                rejectTimer.restart();
                return;
            }
            tf.show(t);
            tf.committed(t);
        }

        // External edits (hand-editing the file, a revert) reach the field,
        // but never while it is the thing being typed into.
        onValueChanged: {
            if (!input.activeFocus)
                tf.show(tf.value);
        }

        Component.onCompleted: tf.show(tf.value)

        width: parent.width
        height: Math.max(Appearance.s(40), Appearance.touchTarget)
        opacity: tf.armed ? 1 : 0.4

        Timer {
            id: rejectTimer

            interval: 900
        }

        StyledText {
            id: tfLabel

            anchors.left: parent.left
            anchors.leftMargin: Appearance.s(12)
            anchors.verticalCenter: parent.verticalCenter
            width: Appearance.s(80)
            text: tf.label
            color: Theme.surfaceFg
            font.pixelSize: Appearance.font.size.small
            elide: Text.ElideRight
        }

        Rectangle {
            anchors.left: tfLabel.right
            anchors.leftMargin: Appearance.s(6)
            anchors.right: parent.right
            anchors.rightMargin: Appearance.s(10)
            anchors.verticalCenter: parent.verticalCenter
            height: Appearance.s(28)
            radius: height / 2
            color: Qt.alpha(Theme.surfaceFg, 0.1)
            border.width: input.activeFocus || rejectTimer.running ? Appearance.s(1) : 0
            border.color: rejectTimer.running ? Theme.urgent : Theme.accent

            Behavior on border.color {
                CAnim {}
            }

            TextInput {
                id: input

                anchors.fill: parent
                anchors.leftMargin: Appearance.s(12)
                anchors.rightMargin: Appearance.s(12)
                verticalAlignment: TextInput.AlignVCenter
                enabled: tf.armed
                color: Theme.surfaceFg
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentFg
                font.family: Appearance.font.family
                font.pixelSize: Appearance.font.size.small
                clip: true
                onActiveFocusChanged: {
                    if (!activeFocus)
                        tf.commit();
                }
                // Esc abandons the edit; the next Esc reaches the window's
                // FocusScope, which closes it.
                Keys.onEscapePressed: {
                    tf.revert();
                    input.focus = false;
                }
                Keys.onReturnPressed: input.focus = false
                Keys.onEnterPressed: input.focus = false

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !input.text
                    text: tf.placeholder
                    color: Theme.surfaceFgDim
                    font.pixelSize: Appearance.font.size.small
                    font.weight: Font.Normal
                }
            }
        }
    }

    // ── The window ──
    LazyLoader {
        active: SettingsUi.open

        FloatingWindow {
            id: win

            title: "Settings"
            visible: true
            color: Theme.surfaceBg
            implicitWidth: Appearance.s(720)
            implicitHeight: Appearance.s(540)

            // Super+Q / a compositor close lands here; without the write-back
            // the loader would keep a hidden window alive forever.
            onVisibleChanged: {
                if (!visible)
                    SettingsUi.open = false;
            }

            FocusScope {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: SettingsUi.open = false

                // ── Sidebar ──
                Rectangle {
                    id: sidebar

                    width: Appearance.s(200)
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    color: Qt.alpha(Theme.surfaceFg, 0.04)

                    Column {
                        anchors.top: parent.top
                        anchors.topMargin: Appearance.s(14)
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Appearance.s(8)
                        anchors.rightMargin: Appearance.s(8)
                        spacing: Appearance.s(2)

                        StyledText {
                            x: Appearance.s(8)
                            text: "Settings"
                            color: Theme.surfaceFg
                            font.pixelSize: Appearance.font.size.large
                            font.weight: Font.DemiBold
                            bottomPadding: Appearance.s(10)
                        }

                        Repeater {
                            model: root.sections

                            Rectangle {
                                id: navRow

                                required property var modelData

                                readonly property bool on: SettingsUi.section === navRow.modelData.key

                                width: parent.width
                                height: Math.max(Appearance.s(32), Appearance.touchTarget)
                                radius: Appearance.s(8)
                                color: navRow.on ? Theme.accent : "transparent"

                                Behavior on color {
                                    CAnim {}
                                }

                                StateLayer {
                                    radius: navRow.radius
                                    color: navRow.on ? Theme.accentFg : Theme.surfaceFg
                                    onClicked: SettingsUi.section = navRow.modelData.key
                                }

                                // The macOS colored icon chip. Fixed hues on
                                // purpose — they are wayfinding, not theme.
                                Rectangle {
                                    id: navChip

                                    x: Appearance.s(6)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Appearance.s(22)
                                    height: Appearance.s(22)
                                    radius: Appearance.s(6)
                                    color: navRow.modelData.tint

                                    FIcon {
                                        anchors.centerIn: parent
                                        icon: navRow.modelData.icon
                                        font.pixelSize: Appearance.s(13)
                                        color: "#ffffff"
                                    }
                                }

                                StyledText {
                                    anchors.left: navChip.right
                                    anchors.leftMargin: Appearance.s(8)
                                    anchors.right: parent.right
                                    anchors.rightMargin: Appearance.s(6)
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: navRow.modelData.label
                                    color: navRow.on ? Theme.accentFg : Theme.surfaceFg
                                    font.pixelSize: Appearance.font.size.small
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.left: sidebar.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: Qt.alpha(Theme.surfaceFg, 0.08)
                }

                // ── Content ──
                Item {
                    anchors.left: sidebar.right
                    anchors.leftMargin: 1
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    StyledText {
                        id: contentTitle

                        x: Appearance.s(20)
                        y: Appearance.s(16)
                        text: root.sectionLabel
                        color: Theme.surfaceFg
                        font.pixelSize: Appearance.font.size.large
                        font.weight: Font.DemiBold
                    }

                    Flickable {
                        anchors.top: contentTitle.bottom
                        anchors.topMargin: Appearance.s(12)
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: Appearance.s(14)
                        anchors.rightMargin: Appearance.s(14)
                        contentHeight: body.item ? body.item.implicitHeight + Appearance.s(16) : 0
                        clip: true
                        interactive: contentHeight > height
                        boundsBehavior: Flickable.StopAtBounds

                        Loader {
                            id: body

                            width: parent.width
                            sourceComponent: {
                                switch (SettingsUi.section) {
                                case "appearance":
                                    return appearanceSec;
                                case "desktop":
                                    return desktopSec;
                                case "tablet":
                                    return tabletSec;
                                case "keyboard":
                                    return keyboardSec;
                                case "weather":
                                    return weatherSec;
                                case "clipboard":
                                    return clipboardSec;
                                case "system":
                                    return systemSec;
                                default:
                                    return appearanceSec;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Sections ──

    Component {
        id: appearanceSec

        Column {
            spacing: Appearance.s(8)

            // A handoff, not a picker: the launcher's `#` mode is the theme
            // picker (full-width rows, stays open across picks). Two pickers
            // for one setting means one of them is always the stale one.
            Card {
                title: "Theme"

                Rectangle {
                    x: Appearance.s(8)
                    width: parent.width - Appearance.s(16)
                    height: Appearance.s(44)
                    radius: Appearance.s(10)
                    color: Qt.alpha(Theme.surfaceFg, 0.06)

                    StateLayer {
                        radius: parent.radius
                        color: Theme.surfaceFg
                        onClicked: Search.openMode("#")
                    }

                    FIcon {
                        id: themeIcon

                        x: Appearance.s(10)
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Theme.isLight ? "sun_max_fill" : "moon_fill"
                        color: Theme.accent
                    }

                    StyledText {
                        anchors.left: themeIcon.right
                        anchors.leftMargin: Appearance.s(10)
                        anchors.right: themeMore.left
                        anchors.rightMargin: Appearance.s(8)
                        anchors.verticalCenter: parent.verticalCenter
                        text: Theme.label(Settings.theme)
                        color: Theme.surfaceFg
                        elide: Text.ElideRight
                    }

                    StyledText {
                        id: themeMore

                        anchors.right: themeChev.left
                        anchors.rightMargin: Appearance.s(8)
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${Theme.available.length} themes`
                        color: Theme.surfaceFgDim
                        font.pixelSize: Appearance.font.size.small
                        font.weight: Font.Normal
                    }

                    FIcon {
                        id: themeChev

                        anchors.right: parent.right
                        anchors.rightMargin: Appearance.s(10)
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "chevron_right"
                        font.pixelSize: Appearance.font.size.small
                        color: Theme.surfaceFgDim
                    }
                }
            }

            Card {
                title: "Size & motion"

                // The slider stops short of the clamp range on both ends: at
                // 0.75 the small font token has rounded past readable, and at
                // 2 you are configuring the shell through a shell you can no
                // longer see around.
                SliderRow {
                    label: "Interface scale"
                    readout: `${root.num(Settings.scale)}×`
                    from: 0.75
                    to: 2
                    step: 0.05
                    value: Settings.scale
                    onMoved: v => Settings.setScale(v)
                }

                // 0 is reduced motion, not broken animation: every duration
                // token collapses to 0ms and transitions resolve in the frame
                // they start.
                SliderRow {
                    label: "Animation speed"
                    readout: Settings.animScale === 0 ? "Off" : `${root.num(Settings.animScale)}×`
                    from: 0
                    to: 3
                    step: 0.1
                    value: Settings.animScale
                    onMoved: v => Settings.setAnimScale(v)
                }

                SliderRow {
                    label: "Trackpad scrolling"
                    readout: `${root.num(Settings.scrollFactor)}×`
                    from: 0.25
                    to: 10
                    step: 0.25
                    value: Settings.scrollFactor
                    onMoved: v => Settings.setScrollFactor(v)
                }
            }
        }
    }

    Component {
        id: desktopSec

        Column {
            spacing: Appearance.s(8)

            Card {
                title: "Counts"

                StepperRow {
                    label: `Workspaces${Settings.hostname ? ` (${Settings.hostname})` : ""}`
                    from: 1
                    to: 20
                    value: Settings.workspaces
                    onStepped: n => Settings.setWorkspaces(n)
                }

                // Per-host: one settings.json is shared by machines whose
                // compositors define 9, 10 and 12 workspaces — the stepper
                // above writes this host's entry, and the compositor-side
                // binds/rules live in config/hypr/lua/hosts/.
                StyledText {
                    x: Appearance.s(12)
                    width: parent.width - Appearance.s(24)
                    text: "Per machine — the count should match the workspaces the compositor actually defines for this host."
                    color: Theme.surfaceFgDim
                    font.pixelSize: Appearance.font.size.small
                    font.weight: Font.Normal
                    wrapMode: Text.WordWrap
                    bottomPadding: Appearance.s(4)
                }

                StepperRow {
                    label: "Launcher results"
                    from: 1
                    to: 20
                    value: Settings.launcherMaxShown
                    onStepped: n => Settings.setLauncherMaxShown(n)
                }

                StepperRow {
                    label: "Overview columns"
                    from: 1
                    to: 12
                    value: Settings.overviewColumns
                    onStepped: n => Settings.setOverviewColumns(n)
                }
            }
        }
    }

    Component {
        id: tabletSec

        Column {
            spacing: Appearance.s(8)

            // Not hidden on machines with neither a detachable keyboard nor a
            // hinge switch: "why is there no keyboard on my tablet" should be
            // answerable from here, and the status line is that answer.
            Card {
                title: "Tablet"

                ChoiceRow {
                    label: "Mode"
                    options: [
                        {
                            value: "auto",
                            label: "Auto"
                        },
                        {
                            value: "tablet",
                            label: "Tablet"
                        },
                        {
                            value: "desktop",
                            label: "Desktop"
                        }
                    ]
                    value: Settings.tabletMode
                    onPicked: v => Settings.setTabletMode(v)
                }

                // What "auto" is currently reading, in words.
                StyledText {
                    x: Appearance.s(12)
                    width: parent.width - Appearance.s(24)
                    text: {
                        if (!Tablet.ready)
                            return "Waiting for the sensor helper…";
                        if (!Tablet.hasTouchscreen)
                            return "No touchscreen on this machine — Auto always resolves to Desktop here.";
                        const bits = [];
                        bits.push(Tablet.keyboardAttached ? "keyboard attached" : "no keyboard");
                        if (Tablet.tabletSwitch)
                            bits.push("folded");
                        return `${Tablet.tablet ? "Touch mode on" : "Touch mode off"} — ${bits.join(", ")}`;
                    }
                    color: Theme.surfaceFgDim
                    font.pixelSize: Appearance.font.size.small
                    font.weight: Font.Normal
                    wrapMode: Text.WordWrap
                    bottomPadding: Appearance.s(4)
                }

                SliderRow {
                    label: "Touch scale"
                    readout: `${root.num(Settings.touchScale)}×`
                    from: 1
                    to: 1.8
                    step: 0.05
                    value: Settings.touchScale
                    onMoved: v => Settings.setTouchScale(v)
                }

                SwitchRow {
                    label: "Edge swipes"
                    checked: Settings.edgeSwipes
                    onSwitched: on => Settings.setEdgeSwipes(on)
                }
            }
        }
    }

    Component {
        id: keyboardSec

        Column {
            spacing: Appearance.s(8)

            Card {
                title: "On-screen keyboard"

                ChoiceRow {
                    label: "Show"
                    options: [
                        {
                            value: "auto",
                            label: "Auto"
                        },
                        {
                            value: "on",
                            label: "On"
                        },
                        {
                            value: "off",
                            label: "Off"
                        }
                    ]
                    value: Settings.osk
                    onPicked: v => Settings.setOsk(v)
                }

                StyledText {
                    x: Appearance.s(12)
                    width: parent.width - Appearance.s(24)
                    text: "Auto raises it only while no physical keyboard is attached. Its height is taken out of the tiled layout, so windows resize around it rather than hiding behind it."
                    color: Theme.surfaceFgDim
                    font.pixelSize: Appearance.font.size.small
                    font.weight: Font.Normal
                    wrapMode: Text.WordWrap
                    bottomPadding: Appearance.s(4)
                }

                SliderRow {
                    label: "Height"
                    readout: `${Math.round(Settings.oskHeight * 100)}% of screen`
                    from: 0.2
                    to: 0.5
                    step: 0.01
                    value: Settings.oskHeight
                    onMoved: v => Settings.setOskHeight(v)
                }
            }
        }
    }

    Component {
        id: weatherSec

        Column {
            spacing: Appearance.s(8)

            Card {
                title: "Weather"

                SwitchRow {
                    label: "Show in calendar"
                    checked: Settings.weather
                    onSwitched: on => Settings.setWeather(on)
                }

                // Dimmed rather than hidden when weather is off — a row that
                // vanishes takes the only evidence a location can be set.
                TextRow {
                    label: "Location"
                    placeholder: "Auto (IP lookup)"
                    armed: Settings.weather
                    value: Settings.weatherPlace
                    strip: true
                    // Empty, or a coordinate pair (two-digit lat, three-digit
                    // lon max — catches place names and swapped pairs).
                    pattern: "^$|^-?\\d{1,2}(\\.\\d+)?,-?\\d{1,3}(\\.\\d+)?$"
                    onCommitted: t => Settings.setWeatherPlace(t)
                }
            }
        }
    }

    Component {
        id: clipboardSec

        Column {
            spacing: Appearance.s(8)

            Card {
                title: "Clipboard"

                SwitchRow {
                    label: "Paste on pick"
                    checked: Settings.clipboardPaste
                    onSwitched: on => Settings.setClipboardPaste(on)
                }

                StyledText {
                    x: Appearance.s(12)
                    width: parent.width - Appearance.s(24)
                    text: "Terminals take Ctrl+Shift+V and everything else Ctrl+V, matched on the class of the window the picker was opened over."
                    color: Theme.surfaceFgDim
                    font.pixelSize: Appearance.font.size.small
                    font.weight: Font.Normal
                    wrapMode: Text.WordWrap
                    bottomPadding: Appearance.s(4)
                }

                // Whitespace is NOT stripped here: `\s` and a literal space
                // are both things a regex may legitimately contain.
                TextRow {
                    label: "Terminals"
                    placeholder: "kitty|foot|…"
                    value: Settings.clipboardPasteTerminals
                    mustCompile: true
                    onCommitted: t => Settings.setClipboardPasteTerminals(t)
                }
            }
        }
    }

    Component {
        id: systemSec

        Column {
            spacing: Appearance.s(8)

            Card {
                title: "System"

                // argv[0] of an execDetached: one executable, no arguments —
                // the pattern rejects "kitty --hold".
                TextRow {
                    label: "Terminal"
                    placeholder: "kitty"
                    value: Settings.terminal
                    pattern: "^[^\\s]+$"
                    onCommitted: t => Settings.setTerminal(t)
                }

                SwitchRow {
                    label: "Suspend on critical battery"
                    checked: Settings.batteryCriticalSuspend
                    onSwitched: on => Settings.setBatteryCriticalSuspend(on)
                }
            }
        }
    }
}
