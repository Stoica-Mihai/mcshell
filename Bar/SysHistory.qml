pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.SysInfo
import qs.Config

// Shared rolling history of system metrics so multiple bar instances
// don't each maintain their own buffer and drift out of sync. The 8-slot
// length matches the WaveformBars width used in the bar capsule — bar[i]
// reads cpuHistory[i] directly with the most recent sample on the right.
Singleton {
    id: root

    readonly property int length: 8
    property var cpuHistory: _empty()

    // Only the bar capsule's "cpu-history" mode consumes this buffer.
    // When the user picks cpu / memory / gpu we skip the slice+push churn
    // entirely (and also reset the buffer below so re-entering cpu-history
    // doesn't show a stale 16s tail).
    readonly property bool active: SysInfo.enabled
        && UserSettings.sysInfoBarMetric === "cpu-history"

    function _empty() {
        const a = [];
        for (let i = 0; i < length; i++) a.push(0);
        return a;
    }

    // Push every poll, not just on cpuChanged — a long idle stretch
    // emits no signal and would otherwise leave the history frozen.
    Timer {
        interval: SysInfo.interval > 0 ? SysInfo.interval : 2000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const next = root.cpuHistory.slice(1);
            next.push(SysInfo.cpuPercent);
            root.cpuHistory = next;
        }
    }

    // Reset to zeros whenever the buffer stops being consumed — either
    // SysInfo polling disabled or bar metric switched away from cpu-history.
    // Otherwise the next activation would render a stale tail until the
    // ring rolls over (~16 s at 2 s interval).
    onActiveChanged: if (!active) cpuHistory = _empty()
}
