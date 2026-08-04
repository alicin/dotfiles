pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// "Is anything using a camera right now" — the other half of the bar's privacy
// pair, next to the mic.
//
// /sys/module/uvcvideo/refcnt is the whole trick: it counts open handles across
// every UVC device at once, so one read covers all four this laptop exposes
// (the FHD webcam plus the IR one for face unlock) without enumerating them or
// caring which is which. Measured at 25µs — 75× cheaper than reading the ASUS
// keyboard backlight, which is a WMI round trip.
//
// Polled, because there is no event: inotify doesn't fire for writes the kernel
// makes to its own attributes, and this file has no sysfs_notify behind it
// either (verified — POLLPRI never arrives on a change).
//
// It counts *opens*, not streaming: an app that opens the camera and pulls no
// frames still shouldn't be doing it unannounced. That direction of error is
// the right one for a privacy light.
//
// Assumes UVC, which is every USB and internal laptop webcam in practice. A
// non-UVC camera (some MIPI sensors on ARM laptops) wouldn't be seen.
Singleton {
    id: root

    readonly property bool inUse: users > 0

    property int users: 0

    // Who has the camera, by name — refcnt can't attribute, so this comes from
    // fuser over the video devices, resolved through /proc/<pid>/comm.
    // Re-probed on every handle-count change, not just the rising edge: a
    // second app joining (1→2) or one of two leaving must refresh the list
    // while the light stays on.
    property list<string> apps: []

    onUsersChanged: {
        if (users > 0) {
            whoProc.running = true;
        } else {
            root.apps = [];
        }
    }

    Process {
        id: whoProc

        command: ["sh", "-c", "fuser /dev/video* 2>/dev/null | tr ' ' '\\n' | sort -u | while read -r p; do cat \"/proc/$p/comm\" 2>/dev/null; done | sort -u"]

        stdout: StdioCollector {
            // The users guard covers a probe that finishes after the camera
            // already closed — it mustn't repopulate a cleared list.
            onStreamFinished: root.apps = root.users > 0 && text.trim() ? text.trim().split("\n") : []
        }
    }

    FileView {
        id: refcnt

        path: "/sys/module/uvcvideo/refcnt"
        blockLoading: true
        blockAllReads: true
        printErrors: false // no uvcvideo module just means no camera
    }

    // 700ms: fast enough that the light is up before you've registered the
    // webcam LED, slow enough to be free at 25µs a read.
    Timer {
        running: true
        interval: 700
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            refcnt.reload();
            root.users = parseInt(refcnt.text(), 10) || 0;
        }
    }
}
