import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SysInfo
import qs.Config
import qs.Widgets

// Sysinfo dropdown panel content for the shared AnimatedPopup.
// Uses parallelogram-styled cards matching the bar/launcher aesthetic.
ColumnLayout {
    id: root

    spacing: 0

    // ── Reusable inline components ───────────────────────
    component SpeedLabel: RowLayout {
        property string arrow
        property color arrowColor
        property string value
        Text { text: arrow; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeMini; font.bold: true; color: arrowColor }
        Text { text: value; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeTiny; font.bold: true; color: Theme.fg }
    }

    // Name + ↓/↑ throughput row, shared by the network and disk sections.
    component MetricSpeedRow: RowLayout {
        property string name
        property real downValue
        property real upValue
        Layout.fillWidth: true
        Layout.preferredHeight: 20
        spacing: Theme.spacingMedium
        Text {
            text: name
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeMini
            color: Theme.fgDim
            Layout.fillWidth: true
        }
        SpeedLabel { arrow: "↓"; arrowColor: Theme.cyan;  value: Theme.formatSpeed(downValue) }
        SpeedLabel { arrow: "↑"; arrowColor: Theme.green; value: Theme.formatSpeed(upValue) }
    }

    // Dim caption text (fgDim, mini) — the panel's repeated label shape.
    component DimLabel: Text {
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeMini
        color: Theme.fgDim
    }

    // Emphasised value text (bold fg, small).
    component ValueText: Text {
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.bold: true
        color: Theme.fg
    }

    // Separator + section heading with a single shared visibility predicate.
    component SysSectionHeader: ColumnLayout {
        property string title
        property bool show: true
        Layout.fillWidth: true
        visible: show
        spacing: 0
        Separator { topMargin: 8 }
        SectionLabel { text: title; Layout.topMargin: 8; Layout.bottomMargin: 2 }
    }

    // ── CPU card ─────────────────────────────────────────
    ParallelogramCard {
        Layout.fillWidth: true
        Layout.preferredHeight: cpuCol.implicitHeight + 16
        backgroundColor: Theme.primaryContainer
        visible: UserSettings.sysInfoShowCpu

        ColumnLayout {
            id: cpuCol
            anchors.fill: parent
            anchors.margins: 8
            spacing: Theme.spacingMicro

            RowLayout {
                Layout.fillWidth: true
                DimLabel {
                    text: "PROCESSOR"
                    Layout.fillWidth: true
                }
                ValueText {
                    text: SysInfo.cpuPercent.toFixed(1) + "%"
                }
            }

            RowLayout {
                Layout.fillWidth: true
                DimLabel {
                    text: SysInfo.cpuCount + " cores \u00B7 " + SysInfo.cpuFreqMhz + " MHz"
                    Layout.fillWidth: true
                }
                DimLabel {
                    text: "Load "
                        + SysInfo.loadAvg1.toFixed(2) + " / "
                        + SysInfo.loadAvg5.toFixed(2) + " / "
                        + SysInfo.loadAvg15.toFixed(2)
                }
            }

            // Per-core bars (skewed to match card geometry)
            Row {
                id: coreRow
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                Layout.topMargin: 4
                spacing: Theme.spacingMicro

                readonly property real barWidth: (width - (SysInfo.cpuCores.length - 1) * 2) / Math.max(1, SysInfo.cpuCores.length)

                Repeater {
                    model: SysInfo.cpuCores.length

                    SkewRect {
                        width: coreRow.barWidth
                        anchors.bottom: parent.bottom
                        skewAmount: Theme.cardSkew

                        readonly property real _load: index < SysInfo.cpuCores.length ? SysInfo.cpuCores[index] : 0
                        height: Math.max(2, _load / 100 * 20)
                        fillColor: Theme.loadColor(_load)

                        Behavior on height { CarouselAnim {} }
                        Behavior on fillColor { ColorAnimation { duration: Theme.animCarousel } }
                    }
                }
            }
        }
    }

    Item { Layout.preferredHeight: 6; visible: UserSettings.sysInfoShowCpu && UserSettings.sysInfoShowMemory }

    // ── Memory card ──────────────────────────────────────
    ParallelogramCard {
        Layout.fillWidth: true
        Layout.preferredHeight: memCol.implicitHeight + 16
        backgroundColor: Theme.primaryContainer
        visible: UserSettings.sysInfoShowMemory

        ColumnLayout {
            id: memCol
            anchors.fill: parent
            anchors.margins: 8
            spacing: Theme.spacingMicro

            RowLayout {
                Layout.fillWidth: true
                DimLabel {
                    text: "MEMORY"
                    Layout.fillWidth: true
                }
                ValueText {
                    text: Theme.toGB(SysInfo.memUsed) + " / " + Theme.toGB(SysInfo.memTotal) + " GB"
                }
            }

            // Fill meter (skewed to match card geometry)
            Item {
                id: memMeter
                Layout.fillWidth: true
                Layout.preferredHeight: 4
                Layout.topMargin: 4

                SkewRect {
                    anchors.fill: parent
                    fillColor: Theme.border
                    skewAmount: Theme.cardSkew
                }

                SkewRect {
                    width: memMeter.width * SysInfo.memPercent / 100
                    height: memMeter.height
                    fillColor: Theme.accent
                    skewAmount: Theme.cardSkew

                    Behavior on width { CarouselAnim {} }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                DimLabel {
                    text: "Swap " + Theme.toGB(SysInfo.swapUsed) + " / " + Theme.toGB(SysInfo.swapTotal) + " GB"
                    Layout.fillWidth: true
                }
                Text {
                    text: SysInfo.memPercent.toFixed(0) + "%"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMini
                    color: Theme.fg
                }
            }
        }
    }

    // ── Thermal section ──────────────────────────────────
    SysSectionHeader { title: "THERMAL"; show: UserSettings.sysInfoShowThermal }

    Repeater {
        model: UserSettings.sysInfoShowThermal ? SysInfo.temperatures : []

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 22

            StatusDot {
                color: Theme.tempColor(modelData.value)
            }

            DimLabel {
                text: modelData.label
                font.pixelSize: Theme.fontSizeTiny
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                text: Theme.formatTemp(modelData.value)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeTiny
                font.bold: true
                color: Theme.tempColor(modelData.value)

                Behavior on color { ColorAnimation { duration: Theme.animCarousel } }
            }
        }
    }

    // ── GPU section ──────────────────────────────────────
    readonly property var _visibleGpus: SysInfo.gpus.filter(g => UserSettings.sysInfoGpuVisible(g.name))
    SysSectionHeader { title: "GPU"; show: UserSettings.sysInfoShowGpu && root._visibleGpus.length > 0 }

    Repeater {
        model: UserSettings.sysInfoShowGpu ? root._visibleGpus : []

        ColumnLayout {
            id: gpuCol
            Layout.fillWidth: true
            // Separate stacked GPU blocks — without this the next header
            // sits closer to the previous block's waveform than to its
            // own sub-line, making it look like it belongs to the GPU above.
            Layout.topMargin: index > 0 ? 8 : 0
            spacing: Theme.spacingMicro

            readonly property real _util: modelData.utilization >= 0 ? modelData.utilization : 0
            readonly property bool _hasVram: modelData.vramTotal > 0
            readonly property color _loadColor: Theme.loadColor(_util)

            // Primary row: dot + vendor + name + util%
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 20

                StatusDot {
                    color: gpuCol._loadColor
                }

                DimLabel {
                    text: modelData.vendor
                    font.bold: true
                }

                DimLabel {
                    // Strip redundant vendor prefix from device name
                    // (NVML's "NVIDIA GeForce ..." and our AMD fallback both duplicate it).
                    text: Theme.stripVendor(modelData.name)
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Text {
                    text: modelData.utilization >= 0 ? modelData.utilization.toFixed(0) + "%" : "—"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeTiny
                    font.bold: true
                    color: gpuCol._loadColor

                    Behavior on color { ColorAnimation { duration: Theme.animCarousel } }
                }
            }

            // Ascending skewed waveform — bar i lights once util crosses
            // its 12.5% threshold, heights ramp up left→right.
            Row {
                id: gpuWave
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.preferredHeight: 18
                spacing: Theme.spacingMicro

                readonly property real _barW: Math.max(2, (width - 7 * spacing) / 8)

                Repeater {
                    model: 8

                    SkewRect {
                        anchors.bottom: parent.bottom
                        width: gpuWave._barW
                        height: Math.max(2, (index + 1) / 8 * parent.height)
                        skewAmount: Theme.cardSkew

                        fillColor: gpuCol._util > (index + 1) * 12.5 - 12.5
                            ? gpuCol._loadColor
                            : Theme.outlineVariant

                        Behavior on fillColor { ColorAnimation { duration: Theme.animCarousel } }
                    }
                }
            }

            // Secondary row: VRAM · power · clock
            DimLabel {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.bottomMargin: 2
                font.pixelSize: Theme.fontSizeTiny
                elide: Text.ElideRight

                text: {
                    const parts = [];
                    if (gpuCol._hasVram)
                        parts.push(Theme.toGB(modelData.vramUsed) + " / " + Theme.toGB(modelData.vramTotal) + " GB VRAM");
                    if (modelData.power > 0)
                        parts.push(modelData.power.toFixed(0) + " W");
                    if (modelData.clock > 0)
                        parts.push(modelData.clock + " MHz");
                    return parts.join(" \u00B7 ");
                }
                visible: text.length > 0
            }
        }
    }

    // ── Network section ──────────────────────────────────
    SysSectionHeader { title: "NETWORK"; show: UserSettings.sysInfoShowNetwork && SysInfo.netInterfaces.length > 0 }

    Repeater {
        model: UserSettings.sysInfoShowNetwork ? SysInfo.netInterfaces : []

        MetricSpeedRow {
            name: modelData.name
            downValue: modelData.rxBytesPerSec
            upValue: modelData.txBytesPerSec
        }
    }

    // ── Disk I/O section ─────────────────────────────────
    // Per whole-disk read/write throughput from /proc/diskstats. Uses the
    // same ↓/↑ SpeedLabel shape as network for visual rhythm.
    SysSectionHeader { title: "DISK I/O"; show: UserSettings.sysInfoShowDisk && SysInfo.diskDevices.length > 0 }

    Repeater {
        model: UserSettings.sysInfoShowDisk ? SysInfo.diskDevices : []

        MetricSpeedRow {
            name: modelData.name
            downValue: modelData.readBytesPerSec
            upValue: modelData.writeBytesPerSec
        }
    }

    // ── Footer ───────────────────────────────────────────
    Separator { Layout.topMargin: 8 }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4

        DimLabel {
            text: SysInfo.processesRunning + " / " + SysInfo.processesTotal + " procs"
            Layout.fillWidth: true
        }
        DimLabel {
            text: "Up " + Theme.formatUptime(SysInfo.uptime)
        }
    }
}
