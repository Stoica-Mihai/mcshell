import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Widgets

FocusScope {
    id: root

    property bool windowOpen: false

    readonly property real fullHeight: content.implicitHeight + Theme.spacingNormal * 2
    readonly property alias nav: nav

    readonly property var _rows: [
        { kind: "check", setting: "wifiCardSignal",   label: "Signal strength" },
        { kind: "check", setting: "wifiCardSecurity", label: "Security type" },
        { kind: "check", setting: "wifiCardStatus",   label: "Connection status" },
        { kind: "check", setting: "wifiCardBand",     label: "Band (2.4 / 5 / 6 GHz)" },
        { kind: "check", setting: "wifiCardChannel",  label: "Channel" },
        { kind: "check", setting: "wifiCardBssid",    label: "BSSID (AP MAC)" },
        { kind: "check", setting: "wifiCardBitrate",  label: "Link bitrate" }
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
            text: "Show on WiFi card"
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
