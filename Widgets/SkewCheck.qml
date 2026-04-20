import QtQuick
import qs.Config

// Diamond-rotated checkbox. Purely visual — parent owns `checked` and
// flips it from its own key handlers. No mouse handling on purpose;
// mcshell's config popups are keyboard-driven.
Item {
    id: root

    property bool checked: false
    property int size: 12

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
}
