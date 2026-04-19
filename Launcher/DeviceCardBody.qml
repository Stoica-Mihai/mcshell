import QtQuick
import QtQuick.Layouts
import qs.Config

// Expanded-card body shared by WiFi and Bluetooth device cards.
// Stacks icon + name + info, with a slotted area below for category-specific
// extras (status hint, password input, MAC address, etc.).
ColumnLayout {
    id: root

    property string iconText: ""
    property color iconColor: Theme.fg
    property real iconOpacity: 1.0
    property string nameText: ""
    property color nameColor: Theme.fg
    property string infoText: ""

    default property alias extras: extrasSlot.data

    spacing: Theme.spacingMedium

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: root.iconText
        font.family: Theme.iconFont
        font.pixelSize: Theme.launcherIconExpanded
        color: root.iconColor
        opacity: root.iconOpacity
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: root.width
        text: root.nameText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeXLarge
        font.bold: true
        color: root.nameColor
        elide: Text.ElideRight
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: root.width
        horizontalAlignment: Text.AlignHCenter
        text: root.infoText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.fgDim
    }

    ColumnLayout {
        id: extrasSlot
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        spacing: Theme.spacingMedium
    }
}
