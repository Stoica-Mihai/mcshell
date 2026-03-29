import QtQuick
import QtQuick.Layouts
import qs.Config

// Reusable toggle row: icon + label + toggle switch.
Item {
    id: root

    property string icon: ""
    property string label: ""
    property string sublabel: ""
    property bool checked: false
    property bool active: true

    signal toggled()

    implicitWidth: parent ? parent.width : 240
    implicitHeight: 40

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: rowMouse.containsMouse ? Theme.bgHover : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10

            // Icon
            Text {
                font.family: "Symbols Nerd Font"
                font.pixelSize: 16
                color: root.checked ? Theme.accent : Theme.fgDim
                text: root.icon
                Layout.alignment: Qt.AlignVCenter
            }

            // Label column
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                Text {
                    text: root.label
                    color: root.active ? Theme.fg : Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    visible: root.sublabel !== ""
                    text: root.sublabel
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            // Toggle switch
            Rectangle {
                id: track
                width: 36
                height: 20
                radius: 10
                color: root.checked ? Theme.accent : Qt.rgba(1, 1, 1, 0.12)
                Layout.alignment: Qt.AlignVCenter

                Behavior on color { ColorAnimation { duration: 150 } }

                Rectangle {
                    id: knob
                    width: 14
                    height: 14
                    radius: 7
                    y: 3
                    x: root.checked ? track.width - width - 3 : 3
                    color: root.checked ? Theme.bgSolid : Theme.fgDim

                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: root.active
            onClicked: root.toggled()
        }
    }
}
