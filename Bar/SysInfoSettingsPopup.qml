import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SysInfo
import qs.Config
import qs.Widgets

// Sysinfo config dropdown content — skewed-morphism variant.
// Keyboard-only navigation: ↑/↓ moves between rows, ←/→ cycles value,
// Enter/Space toggles bool rows.
SettingsPanelBase {
    id: root

    // ── Row dispatch table ──────────────────────────────
    // Each entry describes one focusable row. `kind` drives what keyboard
    // input does via KeyboardRowNav AND how the row's UI is rendered.
    // `section` (optional) starts a new visual section above the row.
    // Per-GPU rows use the `onActivate` escape hatch since their toggle
    // semantics don't fit the default boolean-setting flip.
    rows: {
        const base = [
            { kind: "cycle",  section: "General",     label: "Poll interval",     setting: "sysInfoInterval",  values: [1000, 2000, 5000, 10000], model: ["1 s", "2 s", "5 s", "10 s"] },
            { kind: "cycle",                          label: "Temperature unit",  setting: "sysInfoTempUnit",  values: ["C", "F"],                model: ["°C", "°F"] },
            { kind: "cycle",                          label: "Network units",     setting: "sysInfoNetUnit",   values: ["bytes", "kbytes", "mbytes", "bits"], model: ["bytes", "KB", "MB", "bits"] },
            { kind: "toggle", section: "Bar capsule", label: "Show in bar",       setting: "sysInfoEnabled" },
            { kind: "cycle",                          label: "Bar metric",        setting: "sysInfoBarMetric", values: _barMetricValues,          model: _barMetricLabels },
        ];
        // The 2-column grid of dropdown-section toggles renders separately
        // below, but the row descriptors live in this same array so the
        // keyboard nav indexing stays unified.
        for (let i = 0; i < _checkRows.length; i++) base.push(_checkRows[i]);
        for (let i = 0; i < SysInfo.gpus.length; i++) {
            const name = SysInfo.gpus[i].name;
            base.push({
                kind: "gpu",
                gpuName: name,
                onActivate: () => UserSettings.setSysInfoGpuHidden(name, UserSettings.sysInfoGpuVisible(name))
            });
        }
        return base;
    }

    // Dropdown-section toggles — same row descriptors, also indexed by nav.
    readonly property var _checkRows: [
        { kind: "check", setting: "sysInfoShowCpu",     label: "Processor" },
        { kind: "check", setting: "sysInfoShowMemory",  label: "Memory" },
        { kind: "check", setting: "sysInfoShowThermal", label: "Thermal" },
        { kind: "check", setting: "sysInfoShowGpu",     label: "GPU" },
        { kind: "check", setting: "sysInfoShowNetwork", label: "Network" },
        { kind: "check", setting: "sysInfoShowDisk",    label: "Disk I/O" }
    ]

    // Bar metric options — GPU only offered if at least one GPU is detected.
    readonly property var _barMetricOptions: {
        const opts = [
            { value: "cpu",         label: "CPU load" },
            { value: "cpu-history", label: "CPU history" },
            { value: "memory",      label: "Memory" }
        ];
        if (SysInfo.gpus.length > 0) opts.push({ value: "gpu", label: "GPU load" });
        return opts;
    }
    readonly property var _barMetricValues: _barMetricOptions.map(o => o.value)
    readonly property var _barMetricLabels: _barMetricOptions.map(o => o.label)

    // Start indices into `rows` for sections rendered as their own block.
    readonly property int _idxChecksStart: 5
    readonly property int _idxGpusStart:   _idxChecksStart + _checkRows.length

    // Live preview tile — straight rectangle so it reads as a flat
    // header inside the straight dropdown, with a solid accent bar
    // flush against the left edge.
    Rectangle {
        id: previewTile
        Layout.fillWidth: true
        Layout.preferredHeight: previewGrid.implicitHeight + Theme.spacingMedium * 2
        color: Theme.withAlpha(Theme.accent, 0.08)
        radius: Theme.radiusSmall
        clip: true

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 3
            color: Theme.accent
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
                    return parts.join(" · ");
                }
                color: _gpu && _gpu.utilization > 50 ? Theme.yellow : Theme.fg
            }
        }
    }

    // ── Section header — accent tick + label ───────────
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

    // ── General + Bar capsule rows ─────────────────────
    // Driven from `rows[0..4]` — each descriptor carries its label, the
    // setting it binds to, and (for cycles) the visible model + persisted
    // values. Section headers are emitted when `modelData.section` is set.
    Repeater {
        model: root.rows.slice(0, root._idxChecksStart)

        ColumnLayout {
            required property var modelData
            required property int index
            Layout.fillWidth: true
            spacing: 0

            SectionLabel {
                visible: modelData.section !== undefined
                text: modelData.section || ""
            }

            SettingsRowSlot {
                selected: root.selectedRow === index
                label: modelData.label

                CyclePicker {
                    visible: modelData.kind === "cycle"
                    pillValue: true
                    model: modelData.kind === "cycle" ? modelData.model : []
                    currentIndex: modelData.kind === "cycle"
                        ? Math.max(0, modelData.values.indexOf(UserSettings[modelData.setting]))
                        : 0
                    onIndexChanged: idx => {
                        if (modelData.kind === "cycle")
                            UserSettings[modelData.setting] = modelData.values[idx];
                    }
                }

                SkewToggle {
                    visible: modelData.kind === "toggle"
                    state: modelData.kind === "toggle" && UserSettings[modelData.setting] ? 1 : 0
                }
            }
        }
    }

    // ── Dropdown sections (2-column check grid) ────────
    SectionLabel { text: "Dropdown sections" }

    GridLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.spacingMedium
        Layout.rightMargin: Theme.spacingMedium
        columns: 2
        columnSpacing: Theme.spacingLarge
        rowSpacing: Theme.spacingTiny

        Repeater {
            model: root._checkRows
            SettingsCheckRow {
                required property var modelData
                required property int index
                selected: root.selectedRow === root._idxChecksStart + index
                setting: modelData.setting
                label: modelData.label
            }
        }
    }

    // ── Per-GPU toggles ────────────────────────────────
    SectionLabel {
        text: "GPUs"
        visible: SysInfo.gpus.length > 0
    }

    Repeater {
        model: SysInfo.gpus

        // Custom row — vendor stripe + vendor tag + name + toggle.
        // Can't use SettingsRowSlot because that reserves a single
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
                fillColor: Theme.withAlpha(Theme.accent, 0.08)
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

                SkewToggle {
                    state: UserSettings.sysInfoGpuVisible(modelData.name) ? 1 : 0
                    labels: ["Hidden", "Visible"]
                }
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
