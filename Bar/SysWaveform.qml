import QtQuick
import Quickshell.Services.SysInfo
import qs.Config
import qs.Widgets

// Tiny 8-bar waveform showing CPU core load inside the capsule.
// Each bar represents 2 cores (averaged). Height = load, color = severity.
// Hover shows a one-line tooltip; click toggles the sysinfo dropdown.
Item {
    id: root

    signal clicked()
    signal toggleConfigPopup()

    readonly property bool hovered: mouse.containsMouse
    property bool active: false

    // SysInfo.interval is bound once in shell.qml — not per-screen.

    implicitWidth: wave.implicitWidth
    implicitHeight: Theme.iconSize

    // Metric chosen by UserSettings.sysInfoBarMetric. "gpu" falls back to
    // "cpu" when no GPU is detected so we never render an empty waveform.
    readonly property string _metric: {
        const m = UserSettings.sysInfoBarMetric;
        if (m === "gpu" && !UserSettings.primaryGpu()) return "cpu";
        return m || "cpu";
    }

    // Per-bar load percentage 0..100. Derived once per metric/sample change
    // and consumed by both the heights and per-bar colors below — QML sees
    // SysInfo.cpuCores / SysHistory.cpuHistory / etc. as binding deps and
    // diffs the resulting array against the previous one.
    readonly property var _barLoads: {
        const n = Theme.waveformBarCount;
        const out = new Array(n);
        if (_metric === "cpu") {
            const cores = SysInfo.cpuCores;
            for (let i = 0; i < n; i++) {
                const a = (i * 2)     < cores.length ? cores[i * 2]     : 0;
                const b = (i * 2 + 1) < cores.length ? cores[i * 2 + 1] : 0;
                out[i] = (a + b) / 2;
            }
            return out;
        }
        if (_metric === "cpu-history") {
            const h = SysHistory.cpuHistory;
            for (let i = 0; i < n; i++) out[i] = i < h.length ? h[i] : 0;
            return out;
        }
        // memory / gpu fall through to a threshold style below — heights
        // are derived from a single percentage, not per-bar. Broadcast
        // that one value so the colors path can read it uniformly.
        let pct = 0;
        if (_metric === "memory") pct = SysInfo.memPercent;
        else if (_metric === "gpu") {
            const g = UserSettings.primaryGpu();
            pct = g && g.utilization >= 0 ? g.utilization : 0;
        }
        for (let i = 0; i < n; i++) out[i] = pct;
        return out;
    }

    // Heights as 0..1 ratios. CPU modes scale load directly; threshold
    // modes (memory/gpu) light bars progressively from left to right.
    readonly property var _barHeights: {
        const loads = _barLoads;
        if (_metric === "cpu" || _metric === "cpu-history") {
            const out = new Array(Theme.waveformBarCount);
            for (let i = 0; i < Theme.waveformBarCount; i++) out[i] = loads[i] / 100;
            return out;
        }
        // threshold fill: bar i fills as pct crosses i/n.
        return Theme.thresholdBars(loads[0] / 100);
    }

    // Per-bar colors only matter in CPU modes where each bar has its own
    // load. Memory/GPU stay uniform — return null so WaveformBars uses
    // the single `color` property instead of allocating an 8-entry array.
    readonly property var _barColors: {
        if (_metric === "cpu" || _metric === "cpu-history") {
            const loads = _barLoads;
            const out = new Array(Theme.waveformBarCount);
            for (let i = 0; i < Theme.waveformBarCount; i++) out[i] = Theme.loadColor(loads[i]);
            return out;
        }
        return null;
    }

    readonly property color _uniformColor: {
        if (_metric === "memory") return Theme.loadColor(SysInfo.memPercent);
        if (_metric === "gpu") {
            const g = UserSettings.primaryGpu();
            return Theme.loadColor(g && g.utilization >= 0 ? g.utilization : 0);
        }
        return Theme.accent;
    }

    WaveformBars {
        id: wave
        anchors.centerIn: parent
        model: root._barHeights
        colors: root._barColors
        color: root._uniformColor
    }

    ActiveUnderline { visible: root.active }

    BarClickArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onLeftClicked:  root.clicked()
        onRightClicked: root.toggleConfigPopup()
    }

    ThemedTooltip {
        showWhen: root.hovered && !root.active
        text: root.hovered ? root._tooltipText() : ""
    }

    function _tooltipText() {
        const cpu = SysInfo.cpuPercent.toFixed(0);
        const t = Theme.mainCpuTemp(SysInfo.temperatures);
        const cpuTemp = isNaN(t) ? "" : Theme.formatTemp(t);
        const mem = SysInfo.memPercent.toFixed(0);
        return `CPU ${cpu}%` + (cpuTemp ? ` · ${cpuTemp}` : "") + ` · ${mem}% RAM`;
    }
}
