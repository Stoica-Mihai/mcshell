pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.Config

// Single source of truth for battery state (UPower bindings only). Shared by
// every status bar's capsule so the state isn't recomputed per monitor.
Singleton {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool present: device?.isPresent ?? false
    readonly property bool ready: device?.ready ?? false
    readonly property real rawPercentage: device?.percentage ?? 0
    readonly property int percentage: Theme.percent(rawPercentage)
    readonly property bool charging: device?.state === UPowerDeviceState.Charging
    readonly property bool pluggedIn: charging
        || device?.state === UPowerDeviceState.FullyCharged
        || device?.state === UPowerDeviceState.PendingCharge
    readonly property bool low: percentage <= 20 && !pluggedIn
}
