import QtQuick
import QtQuick.Layouts
import qs.Config

// Centered overlay-dialog header: accent glyph, bold title, dimmed wrapped
// subtitle. Shared by PolkitDialog, BluetoothPairingDialog, ScreenCastPickerDialog.
ColumnLayout {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property int iconSize: Theme.iconSizeLarge

    Layout.fillWidth: true
    spacing: Theme.spacingSmall

    Text {
        Layout.alignment: Qt.AlignHCenter
        visible: root.icon !== ""
        text: root.icon
        font.family: Theme.iconFont
        font.pixelSize: root.iconSize
        color: Theme.accent
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        visible: root.title !== ""
        text: root.title
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLarge
        font.bold: true
        color: Theme.fg
    }

    Text {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter
        visible: root.subtitle !== ""
        text: root.subtitle
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.fgDim
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
    }
}
