import QtQuick

// Tracks a transient status string for a specific target (SSID, MAC, etc.).
// Shared by WiFi and Bluetooth categories.
QtObject {
    property string status: ""
    property string targetId: ""

    function clear() { status = ""; targetId = ""; }
    function autoClear() { _timer.start(); }

    property var _timer: Timer {
        interval: 3000
        onTriggered: { status = ""; targetId = ""; }
    }
}
