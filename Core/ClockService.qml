pragma Singleton

import QtQuick
import Quickshell
import qs.Config

// Single shared clock. One SystemClock for the whole shell instead of one per
// status bar — matters with seconds precision, where N bars would each wake
// every second; this also keeps every bar's time in lockstep.
Singleton {
    id: root

    readonly property alias date: clock.date

    SystemClock {
        id: clock
        precision: UserSettings.clockShowSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }
}
