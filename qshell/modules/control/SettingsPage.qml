import QtQuick
import qs.config
import qs.components
import qs.services

// Settings: the settings.json keys, in the panel rather than in $EDITOR. The
// file has always been live-reloaded, so nothing here needed new plumbing —
// twelve of the thirteen keys were simply unreachable unless you already knew
// the file existed and what was in it.
//
// `clipboardPasteTerminals` was going to be the exception. It is a 64-character
// alternation of window classes, and at the Control Center's old 340 width a
// single-line field showed about thirty-three of them with no validation: a
// mistyped alternation silently sends Ctrl+V to every terminal you own, and you
// find out days later when a paste arrives as a literal ^V. It is in, because
// both halves of that objection went away — the panel is 460 wide now
// (ControlCenter.qml says why), which puts a little over fifty characters in
// the field, and the row refuses anything that doesn't compile as a regex
// instead of storing it and throwing somewhere else later.
//
// The numeric setters debounce their writes (see config/Settings.qml); the
// values still update on the frame you drag them, so the whole shell resizes
// and retimes live under the sliders.
Column {
    id: root

    signal back

    spacing: Appearance.s(8)

    // Trailing zeros off. The three sliders below step by 0.05, 0.1 and 0.25,
    // so any fixed precision is wrong for two of them — "3.50×" for a quarter
    // step, or "1.1×" for a setting that moves in hundredths.
    function num(v: real): string {
        return `${Math.round(v * 100) / 100}`;
    }

    // ── Row shapes ──

    // Label and value on one line, track on its own line underneath. Sharing a
    // line costs the track the label and the readout — measured at 128px and
    // 29px for the widest pair here, leaving ~345px. `scrollFactor` spans 0.25
    // to 10 in quarters, so that is 39 stops 9px apart under a 15px knob: every
    // one of them is reachable by luck rather than by aim. On its own line the
    // track is ~515px and the stops are 13px, which is wider than the knob.
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
                // where the readout claims it did — a continuous track above a
                // quantised number reads as a slider that keeps sticking.
                const raw = sl.from + t * (sl.to - sl.from);
                sl.moved(Math.round(raw / sl.step) * sl.step);
            }
        }
    }

    // One end of a stepper. `armed` rather than the inherited `enabled`: an
    // Item's `enabled` propagates to its children, so switching it off would
    // also stop the StateLayer's hover wash from ever being drawn again in the
    // hierarchy Qt caches it in — dimming the whole button and disarming just
    // the MouseArea keeps the two decisions separate.
    component StepBtn: Item {
        id: btn

        property string glyph: ""
        property bool armed: true

        signal tapped

        width: Appearance.s(26)
        height: Appearance.s(26)
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

    // Small integers get −/+ rather than a slider. Not a width argument — the
    // track here is wide enough for twenty stops. These are the settings you
    // arrive at already knowing the answer to ("twelve workspaces", "six
    // columns"), and a slider makes you hunt for a number you could have typed;
    // it also has no state between "the value" and "where your finger is",
    // which is why dragging one past the value you wanted feels like a miss.
    component StepperRow: Item {
        id: st

        property string label: ""
        property int from: 1
        property int to: 20
        property int value: 0

        signal stepped(int value)

        width: parent.width
        height: Appearance.s(34)

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

            // Fixed width so the −/+ pair doesn't shuffle sideways under the
            // cursor when the count crosses from one digit to two.
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

    component SwitchRow: Item {
        id: sw

        property string label: ""
        property bool checked: false

        signal switched(bool checked)

        width: parent.width
        height: Appearance.s(34)

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

    // Label on the left, pill field on the right — the same shape as the Wi-Fi
    // password row, and one line rather than two: at the width ControlCenter
    // gives this page the field comes out ~415px, and the small font is a
    // monospace at 7.1px per character (measured), so about fifty-four are
    // legible at once. That covers "37.7749,-122.4194" outright and most of the
    // paste-terminals regex.
    //
    // Committed on Return or on losing focus, never per keystroke. `terminal`
    // is read straight into an execDetached, and a launcher `!` fired halfway
    // through retyping it would try to spawn "kit".
    component TextRow: Item {
        id: tf

        property string label: ""
        property string placeholder: ""
        property string value: ""
        property bool armed: true
        // What a committed value must look like, tested after normalisation so
        // it never has to spell out surrounding whitespace. "" accepts
        // anything, including empty.
        property string pattern: ""
        // Drop *interior* whitespace too, for a field whose value is one token
        // that people nonetheless space out by habit — "37.7749, -122.4194".
        // Off by default, and deliberately off for `terminal`: stripping there
        // would quietly turn "kitty --hold" into the single token
        // "kitty--hold", which is exactly the input the pattern exists to
        // reject.
        property bool strip: false
        // The value is itself a regular expression, so it has to compile before
        // it is stored. `pattern` cannot express that — "is valid syntax" is
        // not a shape — and an unbalanced bracket saved to settings.json throws
        // inside whatever service builds the RegExp later, a long way from the
        // field that caused it.
        property bool mustCompile: false

        signal committed(string text)

        // Every programmatic write to the field goes through here, because
        // assigning `text` leaves the caret at the end and a string longer than
        // the field then renders scrolled to its tail. The paste-terminals
        // regex displayed as "…|konsole|terminator|xterm|st", which is the
        // least identifying half of it. Clicking in sets the caret anyway, so
        // nothing is lost by parking it at the head.
        function show(t: string): void {
            input.text = t;
            input.cursorPosition = 0;
        }

        function revert(): void {
            tf.show(tf.value);
        }

        // True when `t` is safe to store. Split out from commit() because both
        // checks fail the same way and the caller only cares that one did.
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
            // Always trimmed — a "kitty " pasted out of a wiki fails to exec
            // with nothing on screen to say why.
            const t = tf.strip ? input.text.replace(/\s+/g, "") : input.text.trim();
            if (t === tf.value) {
                tf.show(t);
                return;
            }
            if (!tf.accepts(t)) {
                // Snapping back on its own looks like the field ate the input,
                // so the border goes red for a beat first. This is the only
                // error channel a settings field has — there is nowhere on a
                // row this size to put a message.
                tf.revert();
                rejectTimer.restart();
                return;
            }
            tf.show(t);
            tf.committed(t);
        }

        // An external edit — hand-editing the file is still the supported way
        // in, and a revert counts too — has to reach the field, but only while
        // it isn't the thing being typed into: rebinding `text` under the caret
        // would swallow the keystroke that just landed.
        onValueChanged: {
            if (!input.activeFocus)
                tf.show(tf.value);
        }

        Component.onCompleted: tf.show(tf.value)

        width: parent.width
        height: Appearance.s(40)
        opacity: tf.armed ? 1 : 0.4

        Timer {
            id: rejectTimer

            // Long enough to register as a deliberate rejection rather than a
            // repaint glitch, short enough that it is gone before you have
            // finished retyping.
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
                // Esc abandons the edit and hands the next Esc to the panel's
                // FocusScope, which pops the page. Focus has to go somewhere
                // that isn't a field, or the panel's key handlers never see it.
                Keys.onEscapePressed: {
                    tf.revert();
                    input.focus = false;
                }
                // A single-line TextInput does not consume arrows or Return on
                // its own — they would reach the popout FocusScope's nav
                // handlers. Same swallow the Wi-Fi password field does.
                Keys.onUpPressed: event => event.accepted = true
                Keys.onDownPressed: event => event.accepted = true
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

    PageHeader {
        title: "Settings"
        onBack: root.back()
    }

    // ── Theme ──
    //
    // A handoff, not a picker. This page grew a 4-column swatch grid first and
    // it worked, but the launcher's `#` mode is the picker now: full-width rows
    // for sixteen themes, each named, and it stays open across picks so you can
    // compare. Two pickers for one setting means one of them is always the
    // stale one, and this is the copy that loses.
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

    // ── Size and motion ──
    Card {
        title: "Size & motion"

        // Appearance clamps this to 0.5–2.5 and the setter agrees, but the
        // slider stops short at both ends: at 0.75 the small font token (11px)
        // has rounded to 8px and stopped being readable, and at 2 the Control
        // Center is already 680px wide with a 68px bar — past that you are
        // configuring the shell through a shell you can no longer see around.
        SliderRow {
            label: "Interface scale"
            readout: `${root.num(Settings.scale)}×`
            from: 0.75
            to: 2
            step: 0.05
            value: Settings.scale
            onMoved: v => Settings.setScale(v)
        }

        // 0 is reduced motion rather than a broken animation: every duration
        // token collapses to 0ms, so transitions still run and still land, they
        // just resolve in the frame they start.
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

    // ── Counts ──
    Card {
        title: "Counts"

        StepperRow {
            label: "Workspaces"
            from: 1
            to: 20
            value: Settings.workspaces
            onStepped: n => Settings.setWorkspaces(n)
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

    // ── Weather ──
    Card {
        title: "Weather"

        SwitchRow {
            label: "Show in calendar"
            checked: Settings.weather
            onSwitched: on => Settings.setWeather(on)
        }

        // Dimmed rather than hidden when weather is off: a row that vanishes
        // takes the only evidence that a location can be set with it, and this
        // card would then be a lone switch with no hint that the fetch has a
        // knob at all.
        TextRow {
            label: "Location"
            placeholder: "Auto (IP lookup)"
            armed: Settings.weather
            value: Settings.weatherPlace
            strip: true
            // Empty, or a coordinate pair. Latitude is at most two digits and
            // longitude three, which is enough to catch the two mistakes people
            // actually make here — a place name, and the pair the wrong way
            // round with a three-digit latitude.
            pattern: "^$|^-?\\d{1,2}(\\.\\d+)?,-?\\d{1,3}(\\.\\d+)?$"
            onCommitted: t => Settings.setWeatherPlace(t)
        }
    }

    // ── Clipboard ──
    Card {
        title: "Clipboard"

        SwitchRow {
            label: "Paste on pick"
            checked: Settings.clipboardPaste
            onSwitched: on => Settings.setClipboardPaste(on)
        }

        // Wrapped, not elided: it is the only thing that says what the field
        // below is a list *of*, and half that sentence is no sentence.
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

        // Whitespace is not stripped here, unlike the other two fields: `\s` and
        // a literal space are both things a regex may legitimately contain, and
        // silently deleting one from a pattern the user wrote is worse than
        // letting them keep a stray space that matches nothing.
        TextRow {
            label: "Terminals"
            placeholder: "kitty|foot|…"
            value: Settings.clipboardPasteTerminals
            mustCompile: true
            onCommitted: t => Settings.setClipboardPasteTerminals(t)
        }
    }

    // ── System ──
    Card {
        title: "System"

        // Goes out as argv[0], so one executable and no arguments — the pattern
        // is there to reject "kitty --hold", which would otherwise fail as an
        // unknown command with the error going nowhere anyone will see it.
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
