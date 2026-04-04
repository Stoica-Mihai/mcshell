import QtQuick
import QtQuick.Layouts
import qs.Config

// Checkmark + label row for device/option selection in settings panels.
// Extends SettingsRow with a standard check icon and elided label.
// Additional children are appended after the label in the RowLayout.
SettingsRow {
    id: root

    required property string label
    property bool isCurrent: false
    property color activeColor: Theme.accent

    Layout.preferredHeight: 30

    Text {
        text: root.isCurrent ? Theme.iconCheck : ""
        font.family: Theme.iconFont
        font.pixelSize: Theme.fontSizeTiny
        color: Theme.green
        Layout.preferredWidth: 14
    }
    Text {
        text: root.label
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: root.isCurrent ? root.activeColor : Theme.fg
        elide: Text.ElideRight
        Layout.fillWidth: true
        maximumLineCount: 1
    }
}
