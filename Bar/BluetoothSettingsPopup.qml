import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Widgets

FocusScope {
    id: root

    property bool windowOpen: false

    readonly property real fullHeight: content.implicitHeight + Theme.spacingNormal * 2

    readonly property var _rows: [
        { kind: "check", setting: "bluetoothCardType",    label: "Device type" },
        { kind: "check", setting: "bluetoothCardStatus",  label: "Connection status" },
        { kind: "check", setting: "bluetoothCardBattery", label: "Battery level" },
        { kind: "check", setting: "bluetoothCardAddress", label: "MAC address" },
        { kind: "check", setting: "bluetoothCardRssi",    label: "Signal (RSSI)" },
        { kind: "check", setting: "bluetoothCardClass",   label: "Class-of-Device" }
    ]

    KeyboardRowNav {
        id: nav
        rows: root._rows
    }

    anchors.fill: parent
    focus: true

    onWindowOpenChanged: if (windowOpen) { nav.reset(); forceActiveFocus(); }

    Keys.onUpPressed:     nav.navigate(-1)
    Keys.onDownPressed:   nav.navigate(1)
    Keys.onReturnPressed: nav.activate()
    Keys.onSpacePressed:  nav.activate()

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Theme.spacingNormal
        spacing: Theme.spacingSmall

        Text {
            text: "Show on Bluetooth card"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeMini
            color: Theme.fgDim
            Layout.fillWidth: true
            Layout.bottomMargin: Theme.spacingTiny
        }

        Repeater {
            model: root._rows
            SettingsCheckRow {
                required property var modelData
                required property int index
                label: modelData.label
                setting: modelData.setting
                selected: nav.selectedRow === index
            }
        }
    }
}
