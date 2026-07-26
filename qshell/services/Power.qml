pragma Singleton

import Quickshell
import Quickshell.Services.UPower

// power-profiles-daemon, and the one place that decides what each profile is
// called and what it looks like — the bar badge, the battery menu and the OSD
// all have to agree, and they used to only by coincidence.
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
}
