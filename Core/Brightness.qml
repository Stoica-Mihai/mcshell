pragma Singleton

import QtQuick
import Quickshell

// Brightness state provider — single source of truth for screen brightness.
// Polls brightnessctl since no native Wayland API exists.
Singleton {
    id: root

    property int value: 0
    property int max: 1
    readonly property int percent: max > 0 ? Math.round(value / max * 100) : 0

    // Track previous value for OSD change detection
    property int _prev: -1
    signal changed()

    function set(pct) {
        setProc.command = ["brightnessctl", "set", pct + "%"];
        setProc.running = true;
    }

    // ── Polling ──

    SafeProcess {
        id: getProc
        command: ["brightnessctl", "get"]
        failMessage: ""
        onRead: data => {
            const val = parseInt(data.trim(), 10);
            if (isNaN(val)) return;
            if (root._prev >= 0 && val !== root._prev) root.changed();
            root._prev = val;
            root.value = val;
        }
    }

    SafeProcess {
        id: maxProc
        command: ["brightnessctl", "max"]
        failMessage: ""
        onRead: data => {
            const val = parseInt(data.trim(), 10);
            if (!isNaN(val) && val > 0) root.max = val;
        }
    }

    SafeProcess {
        id: setProc
        failMessage: "brightnessctl set failed"
        onFinished: getProc.running = true
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            getProc.running = true;
            maxProc.running = true;
        }
    }
}
