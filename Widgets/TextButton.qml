import QtQuick
import qs.Config

// Reusable text button with hover highlight.
// For icon-only buttons, use IconButton instead.
Rectangle {
    id: root

    property string label: ""
    // `primary: true` paints with the accent fill + accentFg bold label.
    property bool primary: false
    property color baseColor: primary ? Theme.accent : Theme.overlay
    property color hoverColor: primary ? Qt.lighter(Theme.accent, 1.1) : Theme.overlayHover
    property color textColor: primary ? Theme.accentFg : Theme.fgDim
    property bool bold: primary

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
