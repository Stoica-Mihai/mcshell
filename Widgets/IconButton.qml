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
        font.family: Theme.iconFont
        font.pixelSize: root.size
        color: mouse.containsMouse && root.hasHover ? root.hoverColor : root.normalColor
        text: root.icon

        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: root.hasHover
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        // First-click grab workaround: on bar startup the initial press gets
        // canceled before release. Firing click on cancel preserves the action.
        onCanceled: root.clicked()
    }
}
