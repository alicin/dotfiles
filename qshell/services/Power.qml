pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.config

// power-profiles-daemon, and the one place that decides what each profile is
// called and what it looks like — the bar badge, the battery menu and the OSD
// all have to agree, and they used to only by coincidence.
//
// Also the battery's own watchdog: warnings on the way down, an optional
// switch to Power Saver on unplug, and a suspend before the machine dies
// mid-write. The shell *is* the notification daemon here, so "nothing told me
// it was at 4%" is a bug it owns — the entire story used to be the bar tinting
// red at 15%.
//
// Distinct from the ASUS platform/fan profile in Asus.qml: this is the CPU
// governor side. Both exist and they are not the same knob.
Singleton {
    id: root

    readonly property int profile: PowerProfiles.profile
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile

    // Power Saver and Balanced always exist; Performance is hardware-dependent.
    readonly property var all: {
        const list = [PowerProfile.PowerSaver, PowerProfile.Balanced];
        if (PowerProfiles.hasPerformanceProfile)
            list.push(PowerProfile.Performance);
        return list;
    }

    function set(p: int): void {
        PowerProfiles.profile = p;
    }

    function label(p: int): string {
        if (p === PowerProfile.PowerSaver)
            return "Power Saver";
        if (p === PowerProfile.Performance)
            return "Performance";
        return "Balanced";
    }

    function glyph(p: int): string {
        if (p === PowerProfile.PowerSaver)
            return "tortoise";
        if (p === PowerProfile.Performance)
            return "hare";
        return "gauge";
    }

    // ── Battery state ──

    readonly property var device: UPower.displayDevice
    readonly property bool haveBattery: device?.isLaptopBattery ?? false
    readonly property int percent: Math.round((device?.percentage ?? 0) * 100)
    readonly property int state: device?.state ?? UPowerDeviceState.Unknown
    readonly property bool charging: state === UPowerDeviceState.Charging || state === UPowerDeviceState.FullyCharged
    // Only act on a reading once UPower actually has one: at startup the
    // percentage is 0 and the state is Unknown, which is indistinguishable
    // from a flat battery and would fire every warning at once.
    readonly property bool known: haveBattery && state !== UPowerDeviceState.Unknown && percent > 0

    // ── Auto profile on plug/unplug ──
    // Off by default: silently overriding a profile someone set by hand is
    // worse than not having the feature at all. The switch is in the battery
    // menu, next to the profiles it drives.
    readonly property bool autoProfile: persist.autoProfile
    // Where to go back to on AC — remembered rather than assumed, so plugging
    // in restores what you actually use rather than parking everyone on
    // Balanced.
    property int acProfile: PowerProfile.Balanced

    function toggleAutoProfile(): void {
        persist.autoProfile = !persist.autoProfile;
        if (persist.autoProfile)
            root.applyAutoProfile();
    }

    function applyAutoProfile(): void {
        if (!root.autoProfile || !root.haveBattery)
            return;
        root.set(root.charging ? root.acProfile : PowerProfile.PowerSaver);
    }

    onChargingChanged: {
        if (!root.autoProfile)
            return;
        if (!root.charging && root.profile !== PowerProfile.PowerSaver)
            root.acProfile = root.profile;
        root.applyAutoProfile();
    }

    // ── Low battery ──

    readonly property int suspendAt: 3

    // Descending thresholds, each fired at most once per discharge. Latched on
    // the lowest level crossed rather than a flag per level, so a battery
    // hovering either side of 20% can't warn twice.
    property int warnedAt: 101

    readonly property var levels: [
        {
            pct: 20,
            summary: "Battery low",
            urgent: false
        },
        {
            pct: 10,
            summary: "Battery very low",
            urgent: true
        },
        {
            pct: 5,
            summary: "Battery critical",
            urgent: true
        }
    ]

    // Through notify-send rather than an internal path: it goes to whichever
    // daemon is up, so a battery warning still lands if this shell is the one
    // that's broken. Critical urgency pierces the shell's own DND.
    function notify(summary: string, body: string, urgent: bool): void {
        Quickshell.execDetached(["notify-send", "-a", "qshell", "-i", "battery-caution", "-u", urgent ? "critical" : "normal", summary, body]);
    }

    function checkBattery(): void {
        if (!root.known)
            return;

        if (root.charging) {
            // A charge resets the ladder: the next discharge warns again from
            // the top.
            root.warnedAt = 101;
            suspendSoon.stop();
            return;
        }

        for (const l of root.levels) {
            if (root.percent <= l.pct && root.warnedAt > l.pct) {
                root.warnedAt = l.pct;
                const secs = root.device?.timeToEmpty ?? 0;
                const eta = secs > 0 ? `About ${Math.round(secs / 60)} minutes left. ` : "";
                const tail = Settings.batteryCriticalSuspend ? `The machine suspends at ${root.suspendAt}%.` : "Plug in soon.";
                root.notify(`${l.summary} — ${root.percent}%`, `${eta}${tail}`, l.urgent);
                break;
            }
        }

        // The critical action proper. Suspending costs a few seconds; letting
        // the battery cut power mid-write can cost the work — and UPower's own
        // critical action isn't configured on this machine.
        if (Settings.batteryCriticalSuspend && root.percent <= root.suspendAt && !suspendSoon.running) {
            root.notify("Suspending — battery critical", `${root.percent}% left. Plug in and press a key to resume.`, true);
            suspendSoon.restart();
        }
    }

    Timer {
        id: suspendSoon

        // Long enough for the notification to appear and be read; short enough
        // not to matter to what's left of the battery.
        interval: 5000
        onTriggered: {
            // Re-checked: five seconds is plenty of time to have plugged in.
            if (!root.charging && root.percent <= root.suspendAt)
                Quickshell.execDetached(["systemctl", "suspend"]);
        }
    }

    onPercentChanged: root.checkBattery()
    onStateChanged: root.checkBattery()

    PersistentProperties {
        id: persist

        reloadableId: "qshellPower"

        property bool autoProfile: false
    }
}
