import QtQuick
import QtQuick.Layouts
import qs.Config

// Renders a list of settings-row descriptors as labelled rows with a
// CyclePicker (kind "cycle") or SkewToggle (kind "toggle") control, plus
// an optional section header. Shared by ClockSettingsPopup and
// SysInfoSettingsPopup. Place inside a ColumnLayout (e.g. SettingsPanelBase).
//
// Each descriptor: { kind, label, setting, section?, values?, model? }.
//   - "cycle": `values[i]` persisted to UserSettings[setting], `model[i]` shown.
//   - "toggle": UserSettings[setting] bool.
// `baseIndex` offsets the keyboard-nav row index when this repeater renders
// only a slice of a larger row table.
Repeater {
    id: rep

    property int selectedRow: -1
    property int baseIndex: 0
    property bool sectionTick: true

    ColumnLayout {
        id: rowItem
        required property var modelData
        required property int index
        Layout.fillWidth: true
        spacing: Theme.spacingTiny

        SectionLabel {
            visible: !!rowItem.modelData.section
            text: rowItem.modelData.section || ""
            tick: rep.sectionTick
            Layout.topMargin: Theme.spacingSmall
        }

        SettingsRowSlot {
            selected: rep.selectedRow === rep.baseIndex + rowItem.index
            label: rowItem.modelData.label

            CyclePicker {
                pillValue: true
                visible: rowItem.modelData.kind === "cycle"
                model: rowItem.modelData.kind === "cycle" ? rowItem.modelData.model : []
                currentIndex: rowItem.modelData.kind === "cycle"
                    ? Math.max(0, rowItem.modelData.values.indexOf(UserSettings[rowItem.modelData.setting]))
                    : 0
                onIndexChanged: idx => {
                    if (rowItem.modelData.kind === "cycle")
                        UserSettings[rowItem.modelData.setting] = rowItem.modelData.values[idx];
                }
            }

            SkewToggle {
                visible: rowItem.modelData.kind === "toggle"
                state: rowItem.modelData.kind === "toggle" && UserSettings[rowItem.modelData.setting] ? 1 : 0
            }
        }
    }
}
