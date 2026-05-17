import QtQuick
import QtQuick.Layouts
import qs.Config

// Header + list-of-SettingsCheckRows settings popup, built on
// SettingsPanelBase. The shape every bar settings popup that only
// toggles booleans takes:
//
//   CheckRowsPopup {
//       headerText: "Show on WiFi card"
//       rows: [
//           { kind: "check", setting: "wifiCardSignal", label: "Signal strength" },
//           ...
//       ]
//   }
//
// `rows` is forwarded straight to the base — the keyboard nav reads the
// same array, so Enter/Space on row N flips `UserSettings[rows[N].setting]`.
SettingsPanelBase {
    id: root

    property string headerText: ""

    Text {
        text: root.headerText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeMini
        color: Theme.fgDim
        Layout.fillWidth: true
        Layout.bottomMargin: Theme.spacingTiny
    }

    Repeater {
        model: root.rows
        SettingsCheckRow {
            required property var modelData
            required property int index
            label: modelData.label
            setting: modelData.setting
            selected: root.selectedRow === index
        }
    }
}
