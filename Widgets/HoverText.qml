import QtQuick
import qs.Config

// Text with hover color transition and built-in click handling.
// Defaults to fgDim → accent on hover. Override normalColor/hoverColor as needed.
Text {
    id: root

    property color normalColor: Theme.fgDim
    property color hoverColor: Theme.accent
    readonly property alias hovered: mouse.containsMouse

    signal clicked()

    font.family: Theme.fontFamily
    color: mouse.containsMouse ? hoverColor : normalColor
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
