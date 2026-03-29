import QtQuick
import qs.Config

// Reusable Nerd Font icon button with hover color change.
Item {
    id: root

    property string icon: ""
    property color normalColor: Theme.fg
    property color hoverColor: Theme.accent
    property int size: Theme.iconSize
    property bool hasHover: true

    signal clicked()

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        id: label
        anchors.centerIn: parent
        font.family: "Symbols Nerd Font"
        font.pixelSize: root.size
        color: mouse.containsMouse && root.hasHover ? root.hoverColor : root.normalColor
        text: root.icon

        Behavior on color { ColorAnimation { duration: 100 } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: root.hasHover
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
