import QtQuick
import QtQuick.Layouts
import qs.Config

// Single centered card shown when a feature is disabled (WiFi off, BT off).
Rectangle {
    id: root

    property string icon: ""
    property string hint: ""

    width: 500
    height: 350
    radius: 14
    color: Theme.bg
    border.width: 1
    border.color: Theme.border

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 12
        width: parent.width - 40

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.icon
            font.family: Theme.iconFont
            font.pixelSize: 48
            color: Theme.red
            opacity: 0.4
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
