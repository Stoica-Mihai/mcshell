import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SysInfo
import qs.Config
import qs.Widgets

// Sysinfo config dropdown content — skewed-morphism variant.
// Keyboard-only navigation: ↑/↓ moves between rows, ←/→ cycles value,
// Enter/Space toggles bool rows.
FocusScope {
    id: root

    property bool windowOpen: false

    readonly property real fullHeight: content.implicitHeight + Theme.spacingNormal * 2

    // ── Row dispatch table ──────────────────────────────
    // Each entry describes one focusable row. `kind` drives what keyboard
    // input does to the row. `model` (when present) is the display labels;
    // `values` is what's persisted in UserSettings.
    readonly property var _rows: {
        const base = [
            { kind: "cycle",  setting: "sysInfoInterval",    values: [1000, 2000, 5000, 10000], model: ["1 s", "2 s", "5 s", "10 s"] },
            { kind: "cycle",  setting: "sysInfoTempUnit",    values: ["C", "F"],                 model: ["\u00B0C", "\u00B0F"] },
            { kind: "cycle",  setting: "sysInfoNetUnit",     values: ["bytes", "bits"],           model: ["bytes", "bits"] },
            { kind: "toggle", setting: "sysInfoEnabled" },
            { kind: "cycle",  setting: "sysInfoBarMetric",   values: _barMetricValues,            model: _barMetricLabels },
            { kind: "check",  setting: "sysInfoShowCpu" },
            { kind: "check",  setting: "sysInfoShowMemory" },
            { kind: "check",  setting: "sysInfoShowThermal" },
            { kind: "check",  setting: "sysInfoShowGpu" },
            { kind: "check",  setting: "sysInfoShowNetwork" },
            { kind: "check",  setting: "sysInfoShowDisk" }
        ];
        for (let i = 0; i < SysInfo.gpus.length; i++) {
            const g = SysInfo.gpus[i];
            base.push({ kind: "gpu", gpuName: g.name });
        }
        return base;
    }
    readonly property int rowCount: _rows.length

    // Bar metric values — GPU option only offered if at least one GPU is detected.
    readonly property var _barMetricValues: SysInfo.gpus.length > 0
        ? ["cpu", "memory", "gpu"] : ["cpu", "memory"]
    readonly property var _barMetricLabels: SysInfo.gpus.length > 0
        ? ["CPU load", "Memory", "GPU load"] : ["CPU load", "Memory"]

    // Fixed indices into _rows so sections can look up their selection state.
    readonly property int _idxInterval:      0
    readonly property int _idxTempUnit:      1
    readonly property int _idxNetUnit:       2
    readonly property int _idxShowInBar:     3
    readonly property int _idxBarMetric:     4
    readonly property int _idxSectionsStart: 5
    readonly property int _idxGpusStart:     11

    property int selectedRow: 0

    // ── Keyboard handlers ──────────────────────────────
    anchors.fill: parent
    focus: true

    onWindowOpenChanged: if (windowOpen) { selectedRow = 0; forceActiveFocus(); }

    Keys.onUpPressed:    selectedRow = (selectedRow - 1 + rowCount) % rowCount
    Keys.onDownPressed:  selectedRow = (selectedRow + 1) % rowCount
    Keys.onLeftPressed:  _adjust(-1)
    Keys.onRightPressed: _adjust(+1)
    Keys.onReturnPressed: _activate()
    Keys.onSpacePressed:  _activate()

    function _adjust(dir) {
        const r = _rows[selectedRow];
        if (!r || r.kind !== "cycle") return;
        const values = r.values;
        const cur = Math.max(0, values.indexOf(UserSettings[r.setting]));
        const next = (cur + dir + values.length) % values.length;
        UserSettings[r.setting] = values[next];
    }

    function _activate() {
        const r = _rows[selectedRow];
        if (!r) return;
        if (r.kind === "toggle" || r.kind === "check") {
            UserSettings[r.setting] = !UserSettings[r.setting];
        } else if (r.kind === "gpu") {
            UserSettings.setSysInfoGpuHidden(r.gpuName, UserSettings.sysInfoGpuVisible(r.gpuName));
        }
    }

    // ── UI ─────────────────────────────────────────────
    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Theme.spacingNormal
        spacing: Theme.spacingSmall

        // Live preview tile — parallelogram card with accent stripe
        ParallelogramCard {
            Layout.fillWidth: true
            Layout.preferredHeight: previewGrid.implicitHeight + Theme.spacingMedium * 2
            backgroundColor: Theme.withAlpha(Theme.accent, 0.08)

            SkewRect {
                x: Theme.spacingSmall
                y: 4
                width: 3
                height: parent.height - 8
                fillColor: Theme.accent
            }

            GridLayout {
                id: previewGrid
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingLarge + 4
                anchors.rightMargin: Theme.spacingMedium
                anchors.topMargin: Theme.spacingMedium
                anchors.bottomMargin: Theme.spacingMedium
                columns: 2
                columnSpacing: Theme.spacingMedium
                rowSpacing: Theme.spacingTiny

                component Key: Text {
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMini
                    color: Theme.fgDim
                }
                component Val: Text {
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeTiny
                    color: Theme.fg
                    Layout.alignment: Qt.AlignRight
                }

                Key { text: "CPU" }
                Val { text: SysInfo.cpuPercent.toFixed(0) + "% · " + (SysInfo.cpuFreqMhz / 1000).toFixed(1) + " GHz" }
                Key { text: "Memory" }
                Val { text: Theme.toGB(SysInfo.memUsed) + " / " + Theme.toGB(SysInfo.memTotal) + " GB" }
                Key { text: "CPU temp" }
                Val {
                    text: {
                        const temps = SysInfo.temperatures;
                        for (let i = 0; i < temps.length; i++) {
                            const lbl = temps[i].label;
                            if (lbl === "Tctl" || lbl === "Package id 0")
                                return Theme.formatTemp(temps[i].value);
                        }
                        return temps.length > 0 ? Theme.formatTemp(temps[0].value) : "—";
                    }
                    color: Theme.yellow
                }
                Key { text: "GPU" }
                Val {
                    readonly property var _gpu: UserSettings.primaryGpu()
                    text: {
                        if (!_gpu) return "—";
                        const parts = [];
                        if (_gpu.utilization >= 0) parts.push(_gpu.utilization.toFixed(0) + "%");
                        if (_gpu.power > 0) parts.push(_gpu.power.toFixed(0) + " W");
                        return parts.join(" \u00B7 ");
                    }
                    color: _gpu && _gpu.utilization > 50 ? Theme.yellow : Theme.fg
                }
            }
        }

        // ── Reusable row components ────────────────────
        component SectionLabel: RowLayout {
            property string text: ""
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacingSmall
            spacing: Theme.spacingSmall

            SkewRect {
                implicitWidth: 10
                implicitHeight: 6
                fillColor: Theme.accent
                opacity: Theme.opacityBody
            }
            Text {
                text: parent.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMini
                color: Theme.fgDim
                Layout.fillWidth: true
            }
        }

        // Row shell with selection stripe + label + right-aligned control.
        component SettingRowBase: Item {
            id: rowBase
            property int rowIndex: -1
            property string label: ""
            default property alias controls: controlsHolder.data

            readonly property bool isSelected: root.selectedRow === rowIndex

            Layout.fillWidth: true
            Layout.preferredHeight: 26

            SkewRect {
                anchors.fill: parent
                fillColor: rowBase.isSelected ? Theme.withAlpha(Theme.accent, 0.08) : "transparent"
                visible: rowBase.isSelected
            }

            SkewRect {
                x: 2; y: 4
                width: 2
                height: parent.height - 8
                fillColor: Theme.accent
                visible: rowBase.isSelected
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingLarge
                anchors.rightMargin: Theme.spacingMedium

                Text {
                    text: rowBase.label
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.fg
                    Layout.fillWidth: true
                }

                Item {
                    id: controlsHolder
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: childrenRect.width
                    implicitHeight: childrenRect.height
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.selectedRow = rowBase.rowIndex
                cursorShape: Qt.PointingHandCursor
            }
        }

        // ── General section ────────────────────────────
        SectionLabel { text: "General" }

        SettingRowBase {
            rowIndex: root._idxInterval
            label: "Poll interval"
            CyclePicker {
                pillValue: true
                model: ["1 s", "2 s", "5 s", "10 s"]
                readonly property var _values: [1000, 2000, 5000, 10000]
                currentIndex: Math.max(0, _values.indexOf(UserSettings.sysInfoInterval))
                onIndexChanged: idx => UserSettings.sysInfoInterval = _values[idx]
            }
        }

        SettingRowBase {
            rowIndex: root._idxTempUnit
            label: "Temperature unit"
            CyclePicker {
                pillValue: true
                model: ["\u00B0C", "\u00B0F"]
                readonly property var _values: ["C", "F"]
                currentIndex: Math.max(0, _values.indexOf(UserSettings.sysInfoTempUnit))
                onIndexChanged: idx => UserSettings.sysInfoTempUnit = _values[idx]
            }
        }

        SettingRowBase {
            rowIndex: root._idxNetUnit
            label: "Network units"
            CyclePicker {
                pillValue: true
                model: ["bytes", "bits"]
                readonly property var _values: ["bytes", "bits"]
                currentIndex: Math.max(0, _values.indexOf(UserSettings.sysInfoNetUnit))
                onIndexChanged: idx => UserSettings.sysInfoNetUnit = _values[idx]
            }
        }

        // ── Bar capsule section ────────────────────────
        SectionLabel { text: "Bar capsule" }

        SettingRowBase {
            rowIndex: root._idxShowInBar
            label: "Show in bar"
            BoolToggle {
                checked: UserSettings.sysInfoEnabled
                onToggled: UserSettings.sysInfoEnabled = !UserSettings.sysInfoEnabled
            }
        }

        SettingRowBase {
            rowIndex: root._idxBarMetric
            label: "Bar metric"
            CyclePicker {
                pillValue: true
                model: root._barMetricLabels
                currentIndex: Math.max(0, root._barMetricValues.indexOf(UserSettings.sysInfoBarMetric))
                onIndexChanged: idx => UserSettings.sysInfoBarMetric = root._barMetricValues[idx]
            }
        }

        // ── Dropdown sections ──────────────────────────
        SectionLabel { text: "Dropdown sections" }

        GridLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.spacingMedium
            Layout.rightMargin: Theme.spacingMedium
            columns: 2
            columnSpacing: Theme.spacingLarge
            rowSpacing: Theme.spacingTiny

            // Same shape as SettingRowBase but compact and check-diamond based.
            component CheckRow: Item {
                property int rowIndex: -1
                property string label: ""
                property string setting: ""

                readonly property bool isSelected: root.selectedRow === rowIndex

                Layout.fillWidth: true
                Layout.preferredHeight: 22

                SkewRect {
                    anchors.fill: parent
                    fillColor: parent.isSelected ? Theme.withAlpha(Theme.accent, 0.08) : "transparent"
                    visible: parent.isSelected
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingSmall
                    anchors.rightMargin: Theme.spacingSmall
                    spacing: Theme.spacingNormal

                    SkewCheck {
                        checked: UserSettings[parent.parent.setting]
                        onToggled: UserSettings[parent.parent.setting] = !UserSettings[parent.parent.setting]
                    }
                    Text {
                        text: parent.parent.label
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.fg
                        Layout.fillWidth: true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.selectedRow = parent.rowIndex
                    cursorShape: Qt.PointingHandCursor
                    z: -1
                }
            }

            CheckRow { rowIndex: root._idxSectionsStart + 0; setting: "sysInfoShowCpu";     label: "Processor" }
            CheckRow { rowIndex: root._idxSectionsStart + 1; setting: "sysInfoShowMemory";  label: "Memory" }
            CheckRow { rowIndex: root._idxSectionsStart + 2; setting: "sysInfoShowThermal"; label: "Thermal" }
            CheckRow { rowIndex: root._idxSectionsStart + 3; setting: "sysInfoShowGpu";     label: "GPU" }
            CheckRow { rowIndex: root._idxSectionsStart + 4; setting: "sysInfoShowNetwork"; label: "Network" }
            CheckRow { rowIndex: root._idxSectionsStart + 5; setting: "sysInfoShowDisk";    label: "Disk I/O" }
        }

        // ── Per-GPU toggles ────────────────────────────
        SectionLabel {
            text: "GPUs"
            visible: SysInfo.gpus.length > 0
        }

        Repeater {
            model: SysInfo.gpus

            // Custom row — vendor stripe + vendor tag + name + toggle.
            // Can't use SettingRowBase because that reserves a single
            // fillWidth label slot; GPU rows need their own layout.
            Item {
                id: gpuRow
                required property var modelData
                required property int index
                readonly property int rowIndex: root._idxGpusStart + index
                readonly property bool isSelected: root.selectedRow === rowIndex

                Layout.fillWidth: true
                Layout.preferredHeight: 26

                SkewRect {
                    anchors.fill: parent
                    fillColor: gpuRow.isSelected ? Theme.withAlpha(Theme.accent, 0.08) : "transparent"
                    visible: gpuRow.isSelected
                }
                SkewRect {
                    x: 2; y: 4
                    width: 2
                    height: parent.height - 8
                    fillColor: Theme.accent
                    visible: gpuRow.isSelected
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingLarge
                    anchors.rightMargin: Theme.spacingMedium
                    spacing: Theme.spacingSmall

                    SkewRect {
                        Layout.preferredWidth: 3
                        Layout.preferredHeight: 14
                        Layout.alignment: Qt.AlignVCenter
                        fillColor: gpuRow._vendorColor(modelData.vendor)
                    }

                    Text {
                        text: modelData.vendor
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMini
                        font.bold: true
                        color: Theme.fgDim
                    }

                    Text {
                        text: (modelData.name || "").replace(/^(NVIDIA|AMD|Intel)\s+/i, "")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.fg
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    BoolToggle {
                        checked: UserSettings.sysInfoGpuVisible(modelData.name)
                        onToggled: UserSettings.setSysInfoGpuHidden(
                            modelData.name,
                            UserSettings.sysInfoGpuVisible(modelData.name))
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.selectedRow = gpuRow.rowIndex
                    cursorShape: Qt.PointingHandCursor
                    z: -1
                }

                function _vendorColor(vendor) {
                    const v = (vendor || "").toLowerCase();
                    if (v.indexOf("nvidia") >= 0) return Theme.green;
                    if (v.indexOf("amd") >= 0)    return Theme.red;
                    if (v.indexOf("intel") >= 0)  return Theme.cyan;
                    return Theme.accent;
                }
            }
        }
    }
}
