pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking

// Centralized notification sender + connection state watchers.
// Any component can send notifications via NotificationDispatcher.send().
Singleton {
    id: root

    // ── Public API ──────────────────────────────────────
    function send(title, body, timeout, urgency) {
        var cmd = ["notify-send", "-t", String(timeout || 3000)];
        if (urgency) cmd.push("-u", urgency);
        cmd.push(title, body);
        Quickshell.execDetached({ command: cmd });
    }

    function sendWithImage(title, body, imagePath, timeout) {
        Quickshell.execDetached({ command: ["notify-send", "-t", String(timeout || 5000),
            "-h", "string:image-path:" + imagePath, title, body] });
    }

    // ── Bluetooth watchers ──────────────────────────────
    Connections {
        target: Bluetooth.defaultAdapter
        function onEnabledChanged() {
            if (!Bluetooth.defaultAdapter) return;
            root.send("Bluetooth", Bluetooth.defaultAdapter.enabled ? "Enabled" : "Disabled", 2000);
        }
    }

    Variants {
        model: Bluetooth.defaultAdapter?.devices.values ?? []
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged() {
                if (!modelData?.name) return;
                root.send("Bluetooth",
                    (modelData.connected ? "Connected to " : "Disconnected from ") + modelData.name, 3000);
            }
        }
    }

    // ── WiFi watchers ───────────────────────────────────
    Connections {
        target: Networking
        function onWifiEnabledChanged() {
            root.send("WiFi", Networking.wifiEnabled ? "Enabled" : "Disabled", 2000);
        }
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
                    (modelData.connected ? "Connected to " : "Disconnected from ") + modelData.name, 3000);
            }
        }
    }
}
