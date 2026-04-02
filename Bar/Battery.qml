import QtQuick
import Quickshell.Services.UPower

// Battery state provider — UPower bindings only.
// UI is handled by SystemCapsule in StatusBar.
Item {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool present: device?.isPresent ?? false
    readonly property bool ready: device?.ready ?? false
    readonly property real rawPercentage: device?.percentage ?? 0
    readonly property int percentage: Math.round(rawPercentage * 100)
    readonly property bool charging: device?.state === UPowerDeviceState.Charging
    readonly property bool pluggedIn: charging
        || device?.state === UPowerDeviceState.FullyCharged
        || device?.state === UPowerDeviceState.PendingCharge
    readonly property bool low: percentage <= 20 && !pluggedIn
}
