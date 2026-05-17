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
        const out = new Array(8);
        if (_metric === "cpu") {
            const cores = SysInfo.cpuCores;
            for (let i = 0; i < 8; i++) {
                const a = (i * 2)     < cores.length ? cores[i * 2]     : 0;
                const b = (i * 2 + 1) < cores.length ? cores[i * 2 + 1] : 0;
                out[i] = (a + b) / 2;
            }
            return out;
        }
        if (_metric === "cpu-history") {
            const h = SysHistory.cpuHistory;
            for (let i = 0; i < 8; i++) out[i] = i < h.length ? h[i] : 0;
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
        for (let i = 0; i < 8; i++) out[i] = pct;
        return out;
    }

    // Heights as 0..1 ratios. CPU modes scale load directly; threshold
    // modes (memory/gpu) light bars progressively from left to right.
    readonly property var _barHeights: {
        const out = new Array(8);
        const loads = _barLoads;
        if (_metric === "cpu" || _metric === "cpu-history") {
            for (let i = 0; i < 8; i++) out[i] = loads[i] / 100;
            return out;
        }
        // threshold fill: bar i fills as pct crosses i/8.
        const pct = loads[0]; // broadcast value
        for (let i = 0; i < 8; i++) {
            const threshold = i / 8;
            out[i] = Math.max(0, Math.min(1, (pct / 100 - threshold) * 8));
        }
        return out;
    }

    // Per-bar colors only matter in CPU modes where each bar has its own
    // load. Memory/GPU stay uniform — return null so WaveformBars uses
    // the single `color` property instead of allocating an 8-entry array.
    readonly property var _barColors: {
        if (_metric === "cpu" || _metric === "cpu-history") {
            const loads = _barLoads;
            const out = new Array(8);
            for (let i = 0; i < 8; i++) out[i] = Theme.loadColor(loads[i]);
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
        const temps = SysInfo.temperatures;
        let cpuTemp = "";
        for (let i = 0; i < temps.length; i++) {
            const lbl = temps[i].label;
            if (lbl === "Tctl" || lbl === "Package id 0") {
                cpuTemp = Theme.formatTemp(temps[i].value);
                break;
            }
        }
        if (!cpuTemp && temps.length > 0)
            cpuTemp = Theme.formatTemp(temps[0].value);
        const mem = SysInfo.memPercent.toFixed(0);
        return `CPU ${cpu}%` + (cpuTemp ? ` · ${cpuTemp}` : "") + ` · ${mem}% RAM`;
    }
}
