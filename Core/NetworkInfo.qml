pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

// Single source of truth for "which Networking device is the WiFi one" plus
// its connected networks. Shared by the bar capsule, the launcher WiFi tab,
// and the notification dispatcher so the lookup isn't recomputed per screen.
Singleton {
    id: root

    readonly property var wifiDevice:
        (Networking.devices?.values ?? []).find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var connectedNetworks:
        (wifiDevice?.networks?.values ?? []).filter(n => n.connected)
    readonly property bool wifiConnected: connectedNetworks.length > 0
}
