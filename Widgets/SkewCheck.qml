import QtQuick
import qs.Config

// Diamond-rotated checkbox. Display-only — parent owns `checked`.
// Emits `toggled(bool newState)` on click.
Item {
    id: root

    property bool checked: false
    property int size: 12

    signal toggled(bool newState)

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.centerIn: parent
        width: root.size
        height: root.size
        rotation: 45
        color: root.checked ? Theme.accent : "transparent"
        border.width: 1.5
        border.color: root.checked ? Theme.accent : Theme.withAlpha(Theme.fg, 0.22)

        Behavior on color { ColorAnimation { duration: Theme.animNormal } }
        Behavior on border.color { ColorAnimation { duration: Theme.animNormal } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
