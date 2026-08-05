import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.config
import qs.components
import qs.services

// Power profile picker (power-profiles-daemon) + charge estimate, plus the ROG
// platform knobs: fan profile, battery charge limit and dGPU mode (asusctl /
// supergfxctl, via the Asus service).
//
// The CPU governor (power-profiles-daemon) and the ASUS platform/fan profile
// are genuinely different settings, so both are listed rather than collapsed.
Column {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool charging: (device?.state ?? 0) === UPowerDeviceState.Charging
    readonly property bool full: (device?.state ?? 0) === UPowerDeviceState.FullyCharged

    // Names and glyphs come from the Power service, not from a list here: the
    // bar badge and the OSD show the same profile, and three private copies of
    // "Performance is the hare" only agree by luck.
    readonly property var profiles: Power.all

    function fmtEta(seconds: real): string {
        if (seconds <= 0)
            return "";
        const h = Math.floor(seconds / 3600);
        const m = Math.round((seconds % 3600) / 60);
        return h > 0 ? `${h}h ${m}m` : `${m}m`;
    }

    width: Appearance.s(300)
    spacing: Appearance.s(2)

    Component.onCompleted: Asus.polling = true
    Component.onDestruction: Asus.polling = false

    // Small label + horizontal segmented picker, used for the three ROG rows.
    component SegRow: Item {
        id: seg

        property string label: ""
        property var options: []
        property string current: ""
        // Optional display mapping; the picked value is always the raw option.
        property var labelFn: null

        signal picked(string value)

        width: parent.width
        height: Appearance.s(56)

        StyledText {
            id: segLabel

            anchors.left: parent.left
            anchors.leftMargin: Appearance.s(8)
            anchors.top: parent.top
            anchors.topMargin: Appearance.s(4)
            text: seg.label
            color: Theme.surfaceFgDim
            font.pixelSize: Appearance.font.size.small
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Appearance.s(8)
            anchors.right: parent.right
            anchors.rightMargin: Appearance.s(8)
            anchors.top: segLabel.bottom
            anchors.topMargin: Appearance.s(4)
            spacing: Appearance.s(4)

            Repeater {
                model: seg.options

                Rectangle {
                    id: chip

                    required property var modelData

                    readonly property bool active: seg.current === modelData

                    width: (seg.width - Appearance.s(16) - (seg.options.length - 1) * Appearance.s(4)) / Math.max(1, seg.options.length)
                    height: Appearance.s(28)
                    radius: Appearance.s(9)
                    color: active ? Theme.accent : Theme.surfaceHoverBg

                    Behavior on color {
                        CAnim {}
                    }

                    StateLayer {
                        radius: chip.radius
                        color: chip.active ? Theme.accentFg : Theme.surfaceFg
                        onClicked: seg.picked(chip.modelData)
                    }

                    StyledText {
                        anchors.centerIn: parent
                        width: parent.width - Appearance.s(8)
                        horizontalAlignment: Text.AlignHCenter
                        text: seg.labelFn ? seg.labelFn(chip.modelData) : chip.modelData
                        color: chip.active ? Theme.accentFg : Theme.surfaceFg
                        font.pixelSize: Appearance.font.size.small
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    Item {
        width: parent.width
        height: Appearance.sizes.menuRowHeight

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: "Power"
            color: Theme.surfaceFg
        }

        StyledText {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            // Always carries a reading: right after unplugging, UPower has no
            // estimate yet (timeToEmpty is 0), and this header used to render
            // an empty string in a menu literally titled "Power".
            text: {
                const pct = `${Math.round((root.device?.percentage ?? 0) * 100)}%`;
                const eta = root.fmtEta(root.charging ? (root.device?.timeToFull ?? 0) : (root.device?.timeToEmpty ?? 0));
                if (eta)
                    return `${pct} · ${root.charging ? `${eta} until full` : `${eta} left`}`;
                if (root.full)
                    return `${pct} · charged`;
                return `${pct} · ${root.charging ? "charging" : "estimating…"}`;
            }
            color: Theme.surfaceFgDim
            font.pixelSize: Appearance.font.size.small
        }
    }

    MenuSeparator {
        width: parent.width
    }

    // Keyboard nav (arrows + Enter via the Popouts FocusScope) walks the
    // profile rows — the one thing in this menu you flip several times a day.
    property int navIdx: -1

    function navMove(d: int): void {
        const n = root.profiles.length;
        if (n === 0)
            return;
        navIdx = navIdx < 0 ? (d > 0 ? 0 : n - 1) : (navIdx + d + n) % n;
    }

    function navActivate(): void {
        if (navIdx >= 0 && navIdx < root.profiles.length)
            Power.set(root.profiles[navIdx]);
    }

    Repeater {
        model: root.profiles

        Item {
            id: profileItem

            required property int modelData
            required property int index

            readonly property bool active: Power.profile === modelData

            width: parent.width
            height: Appearance.sizes.menuRowHeight

            Rectangle {
                anchors.fill: parent
                radius: Appearance.rounding.normal
                color: Theme.surfaceHoverBg
                visible: root.navIdx === profileItem.index
            }

            StateLayer {
                radius: Appearance.rounding.normal
                color: Theme.surfaceFg
                onClicked: Power.set(profileItem.modelData)
            }

            FIcon {
                id: profileGlyph

                x: Appearance.s(8)
                anchors.verticalCenter: parent.verticalCenter
                icon: Power.glyph(profileItem.modelData)
                color: profileItem.active ? Theme.accent : Theme.surfaceFg
            }

            StyledText {
                anchors.left: profileGlyph.right
                anchors.leftMargin: Appearance.s(10)
                anchors.verticalCenter: parent.verticalCenter
                text: Power.label(profileItem.modelData)
                color: Theme.surfaceFg
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: Appearance.s(12)
                anchors.verticalCenter: parent.verticalCenter
                width: Appearance.s(14)
                height: width
                radius: width / 2
                color: profileItem.active ? Theme.accent : "transparent"
                border.width: profileItem.active ? 0 : Math.max(1, Appearance.s(1.5))
                border.color: Theme.surfaceFgDim

                Behavior on color {
                    CAnim {}
                }
            }
        }
    }

    // Follow the wall socket: Power Saver on battery, back to whatever was in
    // use on AC. Off by default and shown right under the profiles it moves,
    // because a shell that silently overrides a profile you set by hand is
    // worse than one that doesn't have the feature.
    Item {
        visible: root.device?.isLaptopBattery ?? false
        width: parent.width
        height: visible ? Appearance.sizes.menuRowHeight : 0

        StyledText {
            id: autoLabel

            anchors.left: parent.left
            anchors.leftMargin: Appearance.s(8)
            anchors.verticalCenter: parent.verticalCenter
            text: "Switch on unplug"
            color: Theme.surfaceFg
        }

        StyledText {
            anchors.left: autoLabel.right
            anchors.leftMargin: Appearance.s(8)
            anchors.right: autoSwitch.left
            anchors.rightMargin: Appearance.s(8)
            anchors.verticalCenter: parent.verticalCenter
            visible: Power.autoProfile
            text: `→ ${Power.label(Power.acProfile)} on AC`
            color: Theme.surfaceFgDim
            font.pixelSize: Appearance.font.size.small
            font.weight: Font.Normal
            elide: Text.ElideRight
        }

        StyledSwitch {
            id: autoSwitch

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: Power.autoProfile
            onToggled: Power.toggleAutoProfile()
        }
    }

    // ── ROG platform (asusctl / supergfxctl) ──
    MenuSeparator {
        visible: Asus.available
        width: parent.width
    }

    SegRow {
        visible: Asus.available && Asus.profiles.length > 0
        label: "Fan profile"
        options: Asus.profiles
        current: Asus.profile
        onPicked: value => Asus.setProfile(value)
    }

    SegRow {
        visible: Asus.available
        label: `Charge limit — ${Asus.chargeLimit}%`
        options: ["60", "80", "100"]
        current: `${Asus.chargeLimit}`
        onPicked: value => Asus.setChargeLimit(parseInt(value, 10))
    }

    SegRow {
        visible: Asus.available && Asus.gpuModes.length > 0
        label: "GPU mode"
        options: Asus.gpuModes
        current: Asus.gpuMode
        // supergfxd's names are too long for four chips at this width, and
        // eliding the *active* one is the worst thing to lose.
        labelFn: v => ({
                Integrated: "iGPU",
                Hybrid: "Hybrid",
                Vfio: "VFIO",
                AsusMuxDgpu: "MUX"
            }[v] ?? v)
        onPicked: value => Asus.setGpuMode(value)
    }

    // supergfxd only reports this once it has accepted a mode change; a
    // notification fires too (from the Asus service), since the menu is
    // usually shut by then.
    Item {
        visible: Asus.gpuPending !== ""
        width: parent.width
        height: visible ? Appearance.s(34) : 0

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: Appearance.s(8)
            anchors.rightMargin: Appearance.s(8)
            anchors.bottomMargin: Appearance.s(4)
            radius: Appearance.rounding.normal
            color: Qt.alpha(Theme.urgent, 0.14)

            FIcon {
                id: pendGlyph

                x: Appearance.s(10)
                anchors.verticalCenter: parent.verticalCenter
                icon: "exclamationmark_triangle"
                font.pixelSize: Appearance.font.size.small
                color: Theme.urgent
            }

            StyledText {
                anchors.left: pendGlyph.right
                anchors.leftMargin: Appearance.s(8)
                anchors.right: parent.right
                anchors.rightMargin: Appearance.s(10)
                anchors.verticalCenter: parent.verticalCenter
                text: Asus.gpuPending
                color: Theme.urgent
                font.pixelSize: Appearance.font.size.small
                elide: Text.ElideRight
            }
        }
    }
}
