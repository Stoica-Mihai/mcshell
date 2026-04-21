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

    // Apply the user-configured poll interval to the SysInfo singleton.
    // Kept here because this file is the bar's always-instantiated SysInfo
    // consumer — the SysInfoPanel is Loader-gated on its dropdown.
    Binding {
        target: SysInfo
        property: "interval"
        value: UserSettings.sysInfoInterval
    }

    implicitWidth: wave.implicitWidth
    implicitHeight: Theme.iconSize

    // Metric chosen by UserSettings.sysInfoBarMetric. "gpu" falls back to
    // "cpu" when no GPU is detected so we never render an empty waveform.
    readonly property string _metric: {
        const m = UserSettings.sysInfoBarMetric;
        if (m === "gpu" && !UserSettings.primaryGpu()) return "cpu";
        return m || "cpu";
    }

    // CPU: per-bar average of two cores, height scales with load.
    // Memory / GPU: threshold style — bar i fills at i*12.5% (VolumeWaveform).
    function _cpuLoad(i) {
        const cores = SysInfo.cpuCores;
        const i0 = i * 2;
        const i1 = i0 + 1;
        const a = i0 < cores.length ? cores[i0] : 0;
        const b = i1 < cores.length ? cores[i1] : 0;
        return (a + b) / 2;
    }
    function _thresholdFill(pct, i) {
        const threshold = i / 8;
        return Math.max(0, Math.min(1, (pct / 100 - threshold) * 8));
    }

    WaveformBars {
        id: wave
        anchors.centerIn: parent

        barHeight: function(i) {
            if (root._metric === "cpu")    return root._cpuLoad(i) / 100 * 14;
            if (root._metric === "memory") return root._thresholdFill(SysInfo.memPercent, i) * 14;
            if (root._metric === "gpu") {
                const g = UserSettings.primaryGpu();
                const util = g && g.utilization >= 0 ? g.utilization : 0;
                return root._thresholdFill(util, i) * 14;
            }
            return 0;
        }
        barColor: function(i) {
            if (root._metric === "cpu") return Theme.loadColor(root._cpuLoad(i));
            if (root._metric === "memory") return Theme.loadColor(SysInfo.memPercent);
            if (root._metric === "gpu") {
                const g = UserSettings.primaryGpu();
                return Theme.loadColor(g && g.utilization >= 0 ? g.utilization : 0);
            }
            return Theme.accent;
        }
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
        return `CPU ${cpu}%` + (cpuTemp ? ` \u00B7 ${cpuTemp}` : "") + ` \u00B7 ${mem}% RAM`;
    }
}
