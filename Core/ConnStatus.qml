pragma Singleton

import QtQuick
import Quickshell

// Connection-status tokens shared by StatusTracker, StatusHintText, and the
// WiFi/Bluetooth launcher categories. Single source so a handler's status
// string and the label/color logic that reads it can't drift apart.
Singleton {
    readonly property string connecting: "connecting"
    readonly property string disconnecting: "disconnecting"
    readonly property string connected: "connected"
    readonly property string disconnected: "disconnected"
    readonly property string failed: "failed"
    readonly property string pairing: "pairing"
    readonly property string paired: "paired"
}
