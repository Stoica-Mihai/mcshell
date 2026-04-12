import QtQuick
import QtQuick.Layouts
import Qs.SysInfo
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

    Item { Layout.preferredHeight: 6 }

    // ── Memory card ──────────────────────────────────────
    ParallelogramCard {
        Layout.fillWidth: true
        Layout.preferredHeight: memCol.implicitHeight + 16
        backgroundColor: Theme.primaryContainer

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
    Separator { Layout.topMargin: 8 }
    SectionLabel { text: "THERMAL" }

    Repeater {
        model: SysInfo.temperatures

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
                text: modelData.value.toFixed(1) + "\u00B0"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeTiny
                font.bold: true
                color: Theme.tempColor(modelData.value)

                Behavior on color { ColorAnimation { duration: Theme.animCarousel } }
            }
        }
    }

    // ── Network section ──────────────────────────────────
    Separator { Layout.topMargin: 8; visible: SysInfo.netInterfaces.length > 0 }
    SectionLabel { text: "NETWORK"; visible: SysInfo.netInterfaces.length > 0 }

    Repeater {
        model: SysInfo.netInterfaces

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
