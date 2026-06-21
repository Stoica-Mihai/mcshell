pragma Singleton

import QtQuick
import Quickshell

// Single source of truth for bar-panel names and their supported IPC modes.
// shell.qml validates dispatch against `modes`; StatusBar.qml owns the
// per-panel dropdown/height descriptors and asserts its key set matches
// `names` at startup so the two halves can never drift apart silently.
// First mode in each list is the default when the caller passes none.
Singleton {
    readonly property var modes: ({
        weather:           ["view", "edit"],
        calendar:          ["view"],
        clockSettings:     ["view"],
        sysInfoSettings:   ["view"],
        wifiSettings:      ["view"],
        bluetoothSettings: ["view"],
        keybinds:          ["view"],
        volume:            ["view"],
        notifications:     ["view"],
        media:             ["view"],
        tray:              ["view"],
        trayicons:         ["view"],
        sysinfo:           ["view"]
    })

    readonly property var names: Object.keys(modes)
}
