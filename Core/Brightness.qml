pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Brightness state provider — single source of truth for screen brightness.
// Uses FileView to watch sysfs backlight files (event-driven, no polling).
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

    // ── Backlight device discovery ──

    property string _device: ""
    property string _brightnessPath: ""
    property string _maxPath: ""

    SafeProcess {
        id: initProc
        command: ["sh", "-c",
            "for dev in /sys/class/backlight/*; do " +
            "if [ -f \"$dev/brightness\" ] && [ -f \"$dev/max_brightness\" ]; then " +
            "echo \"$dev\"; cat \"$dev/brightness\"; cat \"$dev/max_brightness\"; break; fi; done"]
        failMessage: ""
        onRead: data => {
            const lines = data.trim().split("\n");
            if (lines.length >= 3) {
                root._device = lines[0];
                root._brightnessPath = lines[0] + "/brightness";
                root._maxPath = lines[0] + "/max_brightness";

                const val = parseInt(lines[1], 10);
                const m = parseInt(lines[2], 10);
                if (!isNaN(val)) root.value = val;
                if (!isNaN(m) && m > 0) root.max = m;
                root._prev = root.value;
            }
        }
    }

    Component.onCompleted: initProc.running = true

    // ── File watchers (event-driven, no polling) ──

    FileView {
        path: root._brightnessPath
        watchChanges: path !== ""
        onFileChanged: {
            reload();
        }
        onLoaded: {
            const val = parseInt(text().trim(), 10);
            if (!isNaN(val)) {
                if (root._prev >= 0 && val !== root._prev) root.changed();
                root._prev = val;
                root.value = val;
            }
        }
    }

    FileView {
        path: root._maxPath
        onLoaded: {
            const val = parseInt(text().trim(), 10);
            if (!isNaN(val) && val > 0) root.max = val;
        }
    }

    // ── Set brightness ──

    SafeProcess {
        id: setProc
        failMessage: "brightnessctl set failed"
    }
}
