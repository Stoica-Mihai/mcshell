import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Widgets

// WiFi card field-visibility dropdown — opened via right-click on the
// WiFi bar capsule. Each row toggles a UserSettings.wifiCard* flag that
// CategoryWifi reads when composing the focused network's info line.
//
// Keyboard-only navigation: ↑/↓ between rows, Enter/Space toggles.
FocusScope {
    id: root

    property bool windowOpen: false

    readonly property real fullHeight: content.implicitHeight + Theme.spacingNormal * 2

    readonly property var _rows: [
        { kind: "check", setting: "wifiCardSignal" },
        { kind: "check", setting: "wifiCardSecurity" },
        { kind: "check", setting: "wifiCardStatus" },
        { kind: "check", setting: "wifiCardBand" },
        { kind: "check", setting: "wifiCardChannel" },
        { kind: "check", setting: "wifiCardBssid" },
        { kind: "check", setting: "wifiCardBitrate" }
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
            text: "Show on WiFi card"
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

        CheckRow { rowIndex: 0; setting: "wifiCardSignal";   label: "Signal strength" }
        CheckRow { rowIndex: 1; setting: "wifiCardSecurity"; label: "Security type" }
        CheckRow { rowIndex: 2; setting: "wifiCardStatus";   label: "Connection status" }
        CheckRow { rowIndex: 3; setting: "wifiCardBand";     label: "Band (2.4 / 5 / 6 GHz)" }
        CheckRow { rowIndex: 4; setting: "wifiCardChannel";  label: "Channel" }
        CheckRow { rowIndex: 5; setting: "wifiCardBssid";    label: "BSSID (AP MAC)" }
        CheckRow { rowIndex: 6; setting: "wifiCardBitrate";  label: "Link bitrate" }
    }
}
