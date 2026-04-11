import QtQuick
import QtQuick.Layouts
import qs.Config

Rectangle {
    id: root

    property alias text: field.text
    property alias field: field
    property alias echoMode: field.echoMode
    property alias passwordCharacter: field.passwordCharacter
    property string placeholder: ""
    property string icon: ""

    implicitHeight: 40
    radius: Theme.radiusMedium
    color: Theme.bgSolid
    border.width: 1
    border.color: field.activeFocus ? Theme.accent : Theme.border

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingLarge
        anchors.rightMargin: Theme.spacingLarge
        spacing: Theme.spacingNormal

        Text {
            visible: root.icon !== ""
            text: root.icon
            font.family: Theme.iconFont
            font.pixelSize: Theme.fontSizeBody
            color: Theme.fgDim
            Layout.alignment: Qt.AlignVCenter
        }

        TextInput {
            id: field
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.fg
            clip: true
            selectByMouse: true

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.placeholder
                color: Theme.fgDim
                font: parent.font
                visible: !parent.text
            }
        }
    }
}
