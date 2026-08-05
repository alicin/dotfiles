import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// Calendar dropdown for the clock — the one bar module that used to do nothing
// at all when clicked. Pure JS Date arithmetic; no locale plumbing beyond
// Qt.locale(), which is what formats the month and weekday names.
//
// A weather line sits on top, because "what day is it" and "what's it doing
// outside" are the two things people open a menubar clock for. It is fetched
// only while this menu exists (see services/Weather.qml).
Column {
    id: root

    // The month being displayed, as an offset from the current one — arrows
    // and keyboard nav move this, and it snaps back to 0 on close.
    property int monthOffset: 0

    readonly property date today: clock.date
    // Day 1 of the shown month. Constructed from parts so the offset can run
    // past December without any month-length arithmetic here.
    readonly property date shown: new Date(today.getFullYear(), today.getMonth() + monthOffset, 1)

    readonly property int firstWeekday: {
        // Monday-first grid: JS getDay() is Sunday-first.
        const d = root.shown.getDay();
        return (d + 6) % 7;
    }
    readonly property int daysInMonth: new Date(root.shown.getFullYear(), root.shown.getMonth() + 1, 0).getDate()

    // 6 rows always: a month that needs 5 and one that needs 6 would otherwise
    // resize the whole popout between them, and the panel morphs that height.
    readonly property int cells: 42

    width: Appearance.s(300)
    spacing: Appearance.s(2)

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    // Holds the fetch open for as long as the menu is on screen. Counted, so
    // two monitors' menus don't cancel each other.
    Component.onCompleted: Weather.wanted++
    Component.onDestruction: Weather.wanted--

    // ── Weather ──
    Item {
        visible: Settings.weather
        width: parent.width
        height: visible ? Appearance.s(46) : 0

        FIcon {
            id: wGlyph

            x: Appearance.s(4)
            anchors.verticalCenter: parent.verticalCenter
            visible: Weather.valid
            icon: Weather.glyph
            font.pixelSize: Appearance.s(22)
            color: Theme.accent
        }

        Column {
            anchors.left: Weather.valid ? wGlyph.right : parent.left
            anchors.leftMargin: Weather.valid ? Appearance.s(10) : Appearance.s(4)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            StyledText {
                width: parent.width
                text: Weather.valid ? `${Math.round(Weather.temp)}° · ${Weather.label}` : Weather.error || (Weather.loading ? "Checking the weather…" : "Weather")
                color: Theme.surfaceFg
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                visible: Weather.valid
                text: `${Math.round(Weather.high)}° / ${Math.round(Weather.low)}°${Weather.place ? ` · ${Weather.place}` : ""}`
                color: Theme.surfaceFgDim
                font.pixelSize: Appearance.font.size.small
                font.weight: Font.Normal
                elide: Text.ElideRight
            }
        }
    }

    MenuSeparator {
        visible: Settings.weather
        width: parent.width
    }

    // ── Month header ──
    Item {
        width: parent.width
        height: Appearance.sizes.menuRowHeight

        component NavBtn: Item {
            id: nav

            property string glyph: ""

            signal tapped

            width: Appearance.s(28)
            height: Appearance.s(28)
            anchors.verticalCenter: parent?.verticalCenter ?? undefined

            StateLayer {
                radius: width / 2
                color: Theme.surfaceFg
                onClicked: nav.tapped()
            }

            FIcon {
                anchors.centerIn: parent
                icon: nav.glyph
                font.pixelSize: Appearance.font.size.small
                color: Theme.surfaceFg
            }
        }

        StyledText {
            id: monthLabel

            x: Appearance.s(4)
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDate(root.shown, "MMMM yyyy")
            color: Theme.surfaceFg
            font.pixelSize: Appearance.font.size.large
        }

        // Only when it can do something — a "Today" button on today's month is
        // a control that visibly does nothing.
        Rectangle {
            visible: root.monthOffset !== 0
            anchors.left: monthLabel.right
            anchors.leftMargin: Appearance.s(10)
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: todayLabel.implicitWidth + Appearance.s(16)
            implicitHeight: Appearance.s(22)
            radius: height / 2
            color: Theme.surfaceHoverBg

            StateLayer {
                radius: parent.radius
                color: Theme.surfaceFg
                onClicked: root.monthOffset = 0
            }

            StyledText {
                id: todayLabel

                anchors.centerIn: parent
                text: "Today"
                color: Theme.accent
                font.pixelSize: Appearance.font.size.small
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.s(2)

            NavBtn {
                glyph: "chevron_left"
                onTapped: root.monthOffset--
            }

            NavBtn {
                glyph: "chevron_right"
                onTapped: root.monthOffset++
            }
        }
    }

    // ── Weekday header ──
    Row {
        width: parent.width

        Repeater {
            // Monday-first, from the locale's own short day names.
            model: [1, 2, 3, 4, 5, 6, 0]

            StyledText {
                required property int modelData
                required property int index

                width: root.width / 7
                horizontalAlignment: Text.AlignHCenter
                text: Qt.locale().dayName(modelData, Locale.ShortFormat).slice(0, 2)
                // The weekend pair reads dimmer, same as every desktop calendar.
                color: index >= 5 ? Qt.alpha(Theme.surfaceFgDim, 0.7) : Theme.surfaceFgDim
                font.pixelSize: Appearance.font.size.small
                font.weight: Font.Normal
            }
        }
    }

    // ── Day grid ──
    Grid {
        width: parent.width
        columns: 7

        Repeater {
            model: root.cells

            Item {
                id: cell

                required property int index

                readonly property int dayNum: cell.index - root.firstWeekday + 1
                readonly property bool inMonth: dayNum >= 1 && dayNum <= root.daysInMonth
                readonly property bool isToday: inMonth && root.monthOffset === 0 && dayNum === root.today.getDate()
                readonly property bool weekend: (cell.index % 7) >= 5

                width: root.width / 7
                height: Appearance.s(32)

                Rectangle {
                    anchors.centerIn: parent
                    width: Appearance.s(26)
                    height: width
                    radius: width / 2
                    color: cell.isToday ? Theme.accent : "transparent"
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: cell.inMonth
                    text: `${cell.dayNum}`
                    color: cell.isToday ? Theme.accentFg : cell.weekend ? Theme.surfaceFgDim : Theme.surfaceFg
                    font.pixelSize: Appearance.font.size.small
                    font.weight: cell.isToday ? Font.Bold : Font.Normal
                }
            }
        }
    }

    // Keyboard nav from the Popouts FocusScope: arrows page months, Enter
    // returns to today (which is also what Esc's first press does).
    function navMove(d: int): void {
        root.monthOffset += d;
    }

    function navActivate(): void {
        root.monthOffset = 0;
    }

    function navBack(): bool {
        if (root.monthOffset !== 0) {
            root.monthOffset = 0;
            return true;
        }
        return false;
    }
}
