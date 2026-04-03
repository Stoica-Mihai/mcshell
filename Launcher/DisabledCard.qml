import QtQuick
import QtQuick.Layouts
import qs.Config

// Single centered card for status states (disabled, scanning, etc.).
Rectangle {
    id: root

    property string icon: ""
    property string hint: ""
    property color iconColor: Theme.red
    property real iconOpacity: 0.4

    width: 500
    height: 350
    radius: Theme.radiusLarge
    color: Theme.bg
    border.width: 1
    border.color: Theme.border

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.spacingLarge
        width: parent.width - 40

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.icon
            font.family: Theme.iconFont
            font.pixelSize: 48
            color: root.iconColor
            opacity: root.iconOpacity
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.hint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.fgDim
        }
    }
}
