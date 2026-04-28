import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Widgets

// Bluetooth card field-visibility dropdown — opened via right-click on
// the BT bar capsule. Each row toggles a UserSettings.bluetoothCard*
// flag that CategoryBluetooth reads when composing each device's card.
//
// Keyboard-only navigation: ↑/↓ between rows, Enter/Space toggles.
FocusScope {
    id: root

    property bool windowOpen: false

    readonly property real fullHeight: content.implicitHeight + Theme.spacingNormal * 2

    readonly property var _rows: [
        { kind: "check", setting: "bluetoothCardType" },
        { kind: "check", setting: "bluetoothCardStatus" },
        { kind: "check", setting: "bluetoothCardBattery" },
        { kind: "check", setting: "bluetoothCardAddress" },
        { kind: "check", setting: "bluetoothCardRssi" },
        { kind: "check", setting: "bluetoothCardClass" }
    ]

    readonly property alias selectedRow: nav.selectedRow

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

        component CheckRow: Item {
            property int rowIndex: -1
            property string label: ""
            property string setting: ""

            readonly property bool isSelected: root.selectedRow === rowIndex

            Layout.fillWidth: true
            Layout.preferredHeight: 24

            SkewRect {
                anchors.fill: parent
                fillColor: Theme.withAlpha(Theme.accent, 0.08)
                visible: parent.isSelected
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingMedium
                anchors.rightMargin: Theme.spacingMedium
                spacing: Theme.spacingNormal

                SkewCheck { checked: UserSettings[parent.parent.setting] }
                Text {
                    text: parent.parent.label
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.fg
                    Layout.fillWidth: true
                }
            }
        }

        CheckRow { rowIndex: 0; setting: "bluetoothCardType";    label: "Device type" }
        CheckRow { rowIndex: 1; setting: "bluetoothCardStatus";  label: "Connection status" }
        CheckRow { rowIndex: 2; setting: "bluetoothCardBattery"; label: "Battery level" }
        CheckRow { rowIndex: 3; setting: "bluetoothCardAddress"; label: "MAC address" }
        CheckRow { rowIndex: 4; setting: "bluetoothCardRssi";    label: "Signal (RSSI)" }
        CheckRow { rowIndex: 5; setting: "bluetoothCardClass";   label: "Class-of-Device" }
    }
}
