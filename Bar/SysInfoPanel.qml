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
    component SectionLabel: Text {
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeMini
        color: Theme.fgDim
        Layout.topMargin: 8
        Layout.bottomMargin: 2
    }

    component SpeedLabel: RowLayout {
        property string arrow
        property color arrowColor
        property string value
        Text { text: arrow; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeMini; font.bold: true; color: arrowColor }
        Text { text: value; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeTiny; font.bold: true; color: Theme.fg }
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
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "PROCESSOR"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMini
                    color: Theme.fgDim
                    Layout.fillWidth: true
                }
                Text {
                    text: SysInfo.cpuPercent.toFixed(1) + "%"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                    color: Theme.fg
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: SysInfo.cpuCount + " cores \u00B7 " + SysInfo.cpuFreqMhz + " MHz"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMini
                    color: Theme.fgDim
                    Layout.fillWidth: true
                }
                Text {
                    text: "Load " + SysInfo.loadAvg1.toFixed(2)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMini
                    color: Theme.fgDim
                }
            }

            // Per-core bars (skewed to match card geometry)
            Row {
                id: coreRow
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                Layout.topMargin: 4
                spacing: 2

                readonly property real barWidth: (width - (SysInfo.cpuCores.length - 1) * 2) / Math.max(1, SysInfo.cpuCores.length)

                Repeater {
                    model: SysInfo.cpuCores.length

                    Rectangle {
                        width: coreRow.barWidth
                        anchors.bottom: parent.bottom
                        radius: 1.5

                        readonly property real _load: index < SysInfo.cpuCores.length ? SysInfo.cpuCores[index] : 0
                        height: Math.max(2, _load / 100 * 20)
                        color: Theme.loadColor(_load)

                        transform: Matrix4x4 {
                            matrix: Qt.matrix4x4(
                                1, Theme.cardSkew, 0, -Theme.cardSkew * parent.height / 2,
                                0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1
                            )
                        }

                        Behavior on height { NumberAnimation { duration: Theme.animCarousel; easing.type: Easing.OutCubic } }
                        Behavior on color  { ColorAnimation  { duration: Theme.animCarousel } }
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
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "MEMORY"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMini
                    color: Theme.fgDim
                    Layout.fillWidth: true
                }
                Text {
                    text: Theme.toGB(SysInfo.memUsed) + " / " + Theme.toGB(SysInfo.memTotal) + " GB"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                    color: Theme.fg
                }
            }

            // Fill meter (skewed to match card geometry)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 4
                Layout.topMargin: 4
                radius: 2
                color: Theme.border

                transform: Matrix4x4 {
                    matrix: Qt.matrix4x4(
                        1, Theme.cardSkew, 0, -Theme.cardSkew * 2,
                        0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1
                    )
                }

                Rectangle {
                    width: parent.width * SysInfo.memPercent / 100
                    height: parent.height
                    radius: 2
                    color: Theme.accent

                    Behavior on width { NumberAnimation { duration: Theme.animCarousel; easing.type: Easing.OutCubic } }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                Text {
                    text: "Swap " + Theme.toGB(SysInfo.swapUsed) + " / " + Theme.toGB(SysInfo.swapTotal) + " GB"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMini
                    color: Theme.fgDim
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
    Separator { Layout.topMargin: 8; visible: UserSettings.sysInfoShowThermal }
    SectionLabel { text: "THERMAL"; visible: UserSettings.sysInfoShowThermal }

    Repeater {
        model: UserSettings.sysInfoShowThermal ? SysInfo.temperatures : []

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 22

            Rectangle {
                width: 6; height: 6; radius: 3
                color: Theme.tempColor(modelData.value)

                Behavior on color { ColorAnimation { duration: Theme.animCarousel } }
            }

            Text {
                text: modelData.label
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeTiny
                color: Theme.fgDim
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
    readonly property var _visibleGpus: {
        const src = SysInfo.gpus;
        const out = [];
        for (let i = 0; i < src.length; i++) {
            if (UserSettings.sysInfoGpuVisible(src[i].name)) out.push(src[i]);
        }
        return out;
    }
    Separator { Layout.topMargin: 8; visible: UserSettings.sysInfoShowGpu && root._visibleGpus.length > 0 }
    SectionLabel { text: "GPU"; visible: UserSettings.sysInfoShowGpu && root._visibleGpus.length > 0 }

    Repeater {
        model: UserSettings.sysInfoShowGpu ? root._visibleGpus : []

        ColumnLayout {
            id: gpuCol
            Layout.fillWidth: true
            // Separate stacked GPU blocks — without this the next header
            // sits closer to the previous block's waveform than to its
            // own sub-line, making it look like it belongs to the GPU above.
            Layout.topMargin: index > 0 ? 8 : 0
            spacing: 2

            readonly property real _util: modelData.utilization >= 0 ? modelData.utilization : 0
            readonly property bool _hasVram: modelData.vramTotal > 0
            readonly property color _loadColor: Theme.loadColor(_util)

            // Primary row: dot + vendor + name + util%
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 20

                Rectangle {
                    width: 6; height: 6; radius: 3
                    color: gpuCol._loadColor

                    Behavior on color { ColorAnimation { duration: Theme.animCarousel } }
                }

                Text {
                    text: modelData.vendor
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMini
                    font.bold: true
                    color: Theme.fgDim
                }

                Text {
                    // Strip redundant vendor prefix from device name
                    // (NVML's "NVIDIA GeForce ..." and our AMD fallback both duplicate it).
                    text: modelData.name.replace(/^(NVIDIA|AMD|Intel)\s+/i, "")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMini
                    color: Theme.fgDim
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
                spacing: 2

                readonly property real _barW: Math.max(2, (width - 7 * spacing) / 8)

                Repeater {
                    model: 8

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: gpuWave._barW
                        height: Math.max(2, (index + 1) / 8 * parent.height)
                        radius: 1.5

                        color: gpuCol._util > (index + 1) * 12.5 - 12.5
                            ? gpuCol._loadColor
                            : Theme.outlineVariant

                        transform: Matrix4x4 {
                            matrix: Qt.matrix4x4(
                                1, Theme.cardSkew, 0, -Theme.cardSkew * parent.height / 2,
                                0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1
                            )
                        }

                        Behavior on color { ColorAnimation { duration: Theme.animCarousel } }
                    }
                }
            }

            // Secondary row: VRAM · power · clock
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.bottomMargin: 2
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeTiny
                color: Theme.fgDim
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
    Separator { Layout.topMargin: 8; visible: UserSettings.sysInfoShowNetwork && SysInfo.netInterfaces.length > 0 }
    SectionLabel { text: "NETWORK"; visible: UserSettings.sysInfoShowNetwork && SysInfo.netInterfaces.length > 0 }

    Repeater {
        model: UserSettings.sysInfoShowNetwork ? SysInfo.netInterfaces : []

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            spacing: Theme.spacingMedium

            Text {
                text: modelData.name
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMini
                color: Theme.fgDim
                Layout.fillWidth: true
            }

            SpeedLabel { arrow: "\u2193"; arrowColor: Theme.cyan;  value: Theme.formatSpeed(modelData.rxBytesPerSec) }
            SpeedLabel { arrow: "\u2191"; arrowColor: Theme.green; value: Theme.formatSpeed(modelData.txBytesPerSec) }
        }
    }

    // ── Disk I/O section ─────────────────────────────────
    // Per whole-disk read/write throughput from /proc/diskstats. Uses the
    // same ↓/↑ SpeedLabel shape as network for visual rhythm.
    Separator { Layout.topMargin: 8; visible: UserSettings.sysInfoShowDisk && SysInfo.diskDevices.length > 0 }
    SectionLabel { text: "DISK I/O"; visible: UserSettings.sysInfoShowDisk && SysInfo.diskDevices.length > 0 }

    Repeater {
        model: UserSettings.sysInfoShowDisk ? SysInfo.diskDevices : []

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            spacing: Theme.spacingMedium

            Text {
                text: modelData.name
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMini
                color: Theme.fgDim
                Layout.fillWidth: true
            }

            SpeedLabel { arrow: "\u2193"; arrowColor: Theme.cyan;  value: Theme.formatSpeed(modelData.readBytesPerSec) }
            SpeedLabel { arrow: "\u2191"; arrowColor: Theme.green; value: Theme.formatSpeed(modelData.writeBytesPerSec) }
        }
    }

    // ── Footer ───────────────────────────────────────────
    Separator { Layout.topMargin: 8 }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4

        Text {
            text: SysInfo.processesTotal + " procs"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeMini
            color: Theme.fgDim
            Layout.fillWidth: true
        }
        Text {
            text: "Up " + Theme.formatUptime(SysInfo.uptime)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeMini
            color: Theme.fgDim
        }
    }
}
