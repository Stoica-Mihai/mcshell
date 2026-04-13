import QtQuick
import qs.Config

// Reusable text button with hover highlight.
// For icon-only buttons, use IconButton instead.
Rectangle {
    id: root

    property string label: ""
    property color baseColor: Theme.overlay
    property color hoverColor: Theme.overlayHover
    property color textColor: Theme.fgDim
    property bool bold: false

    signal clicked()

    width: buttonText.implicitWidth + 24
    height: 30
    radius: Theme.radiusSmall
    color: mouse.containsMouse ? root.hoverColor : root.baseColor

    Text {
        id: buttonText
        anchors.centerIn: parent
        text: root.label
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.bold: root.bold
        color: root.textColor
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
