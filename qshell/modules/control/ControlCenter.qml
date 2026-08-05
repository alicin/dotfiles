import QtQuick
import qs.config
import qs.components

// Control Center: a home screen plus drill-down pages for the three things
// that used to be their own bar dropdowns — sound, Bluetooth, KDE Connect.
// One panel instead of four, and the bar keeps only what's worth glancing at.
//
// Navigation is an iOS-style push: home parallaxes out to the left at a third
// of the speed while the page slides in from the right, and the panel morphs
// to the new height. Both live in the same clipped Item, so the whole thing is
// two x offsets and an opacity — no window resizing, which the `qshell:.*`
// layer rule would animate underneath us.
Item {
    id: root

    // Set from outside (the bar's IPC handler) to open straight onto a page.
    property string requestedPage: ""

    // "" is home.
    property string page: ""
    // Outlives `page` for the length of the slide back, so the page doesn't
    // blank out halfway through the animation.
    property string shownPage: ""

    // Height only animates once the user has actually navigated. The first
    // layout pass arrives at home's height from zero, and animating *that*
    // plays a grow every time the menu opens — the exact bug the popout
    // window's constant height was introduced to kill.
    property bool morph: false

    property real slide: page === "" ? 0 : 1

    // Assignment order matters: `morph` has to be true before `page` changes,
    // or the height Behavior is still disabled when the binding re-evaluates.
    function go(name: string): void {
        morph = true;
        page = name;
    }

    // Deliberately not `go()`: this fires while the component is being built
    // (opening straight onto a page), and enabling the morph there would
    // animate the very first layout.
    onRequestedPageChanged: page = requestedPage

    // Esc peels one layer — page back to home — before the next Esc closes
    // the panel. Called by the Popouts FocusScope, which owns the key.
    function navBack(): bool {
        if (page !== "") {
            go("");
            return true;
        }
        return false;
    }

    onPageChanged: {
        if (page !== "")
            shownPage = page;
    }

    onSlideChanged: {
        if (slide < 0.005 && page === "")
            shownPage = "";
    }

    // One width for home and every page. It was 340, which fit two tiles across
    // and forced everything else to stack: three rows of toggles, screenshot
    // and record on separate rows, one slider per line. The panel got long
    // enough that the bottom of it was below the fold on a laptop screen.
    //
    // 460 buys a row of three toggles, all six capture buttons on one line, and
    // volume beside the microphone — which is four rows of height recovered for
    // 120px of width nobody was using. It is also what the Settings page needed
    // for its "label ………… value" rows, so the two agree and the panel no longer
    // changes width when you navigate.
    readonly property int homeWidth: Appearance.s(460)

    implicitWidth: root.homeWidth
    implicitHeight: page === "" ? home.implicitHeight : (detail.item?.implicitHeight ?? home.implicitHeight)
    clip: true

    Behavior on slide {
        Anim {
            duration: Appearance.d(320)
            curve: Appearance.anim.curves.emphasized
        }
    }

    Behavior on implicitHeight {
        enabled: root.morph

        Anim {
            duration: Appearance.d(320)
            curve: Appearance.anim.curves.emphasized
        }
    }

    Home {
        id: home

        width: root.width
        // Trails rather than tracks the page: the slower counter-slide is what
        // reads as one screen sitting behind the other.
        x: -root.slide * root.width * 0.3
        opacity: 1 - root.slide
        visible: opacity > 0.005
        onNavigate: name => root.go(name)
    }

    Loader {
        id: detail

        width: root.width
        x: (1 - root.slide) * root.width
        opacity: root.slide
        visible: active && opacity > 0.005
        active: root.shownPage !== ""

        sourceComponent: {
            switch (root.shownPage) {
            case "audio":
                return audioPage;
            case "bluetooth":
                return btPage;
            case "kdeconnect":
                return kdecPage;
            case "display":
                return displayPage;
            case "settings":
                return settingsPage;
            default:
                return null;
            }
        }
    }

    Component {
        id: audioPage

        AudioPage {
            onBack: root.go("")
        }
    }

    Component {
        id: btPage

        BluetoothPage {
            onBack: root.go("")
        }
    }

    Component {
        id: kdecPage

        KdeConnectPage {
            onBack: root.go("")
        }
    }

    Component {
        id: displayPage

        DisplayPage {
            onBack: root.go("")
        }
    }

    Component {
        id: settingsPage

        SettingsPage {
            onBack: root.go("")
        }
    }
}
