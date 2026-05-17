pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.SysInfo

// Shared rolling history of system metrics so multiple bar instances
// don't each maintain their own buffer and drift out of sync. The 8-slot
// length matches the WaveformBars width used in the bar capsule — bar[i]
// reads cpuHistory[i] directly with the most recent sample on the right.
Singleton {
    id: root

    readonly property int length: 8
    property var cpuHistory: _empty()

    function _empty() {
        const a = [];
        for (let i = 0; i < length; i++) a.push(0);
        return a;
    }

    // Push every poll, not just on cpuChanged — a long idle stretch
    // emits no signal and would otherwise leave the history frozen.
    Timer {
        interval: SysInfo.interval > 0 ? SysInfo.interval : 2000
        running: SysInfo.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const next = root.cpuHistory.slice(1);
            next.push(SysInfo.cpuPercent);
            root.cpuHistory = next;
        }
    }

    // Reset to zeros when polling is disabled so a stale tail doesn't
    // hang around if the user toggles SysInfo back on later.
    Connections {
        target: SysInfo
        function onEnabledChanged() {
            if (!SysInfo.enabled) root.cpuHistory = root._empty();
        }
    }
}
