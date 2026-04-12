pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import qs.Config

// Centralized notification sender + connection state watchers.
// Any component can send notifications via NotificationDispatcher.send().
Singleton {
    id: root

    // ── Public API ──────────────────────────────────────
    function send(title, body, timeout, urgency) {
        var cmd = ["notify-send", "-a", "mcshell", "-t", String(timeout || Theme.notifNormal)];
        if (urgency) cmd.push("-u", urgency);
        cmd.push(title, body);
        Quickshell.execDetached({ command: cmd });
    }

    function sendWithImage(title, body, imagePath, timeout) {
        Quickshell.execDetached({ command: ["notify-send", "-a", "mcshell", "-t", String(timeout || Theme.notifLong),
            "-h", "string:image-path:" + imagePath, title, body] });
    }

    // ── Bluetooth watchers ──────────────────────────────
    // Debounce — BlueZ bounces enabled during state transitions
    Timer {
        id: _btDebounce
        interval: 500
        onTriggered: {
            if (!Bluetooth.defaultAdapter) return;
            root.send("Bluetooth", Bluetooth.defaultAdapter.enabled ? "Enabled" : "Disabled", Theme.notifShort);
        }
    }
    Connections {
        target: Bluetooth.defaultAdapter
        function onEnabledChanged() { _btDebounce.restart(); }
    }

    Variants {
        model: Bluetooth.defaultAdapter?.devices.values ?? []
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged() {
                if (!modelData?.name) return;
                root.send("Bluetooth",
                    (modelData.connected ? "Connected to " : "Disconnected from ") + modelData.name, Theme.notifNormal);
            }
        }
    }

    // ── WiFi watchers ───────────────────────────────────
    // Debounce — NM bounces wifiEnabled during state transitions
    Timer {
        id: _wifiDebounce
        interval: 500
        onTriggered: root.send("WiFi", Networking.wifiEnabled ? "Enabled" : "Disabled", Theme.notifShort)
    }
    Connections {
        target: Networking
        function onWifiEnabledChanged() { _wifiDebounce.restart(); }
    }

    readonly property var _wifiDevice: {
        const devs = Networking.devices?.values ?? [];
        for (let i = 0; i < devs.length; i++)
            if (devs[i].type === DeviceType.Wifi) return devs[i];
        return null;
    }

    Variants {
        model: root._wifiDevice?.networks.values ?? []
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged() {
                if (!modelData?.name) return;
                root.send("WiFi",
                    (modelData.connected ? "Connected to " : "Disconnected from ") + modelData.name, Theme.notifNormal);
            }
        }
    }
}
