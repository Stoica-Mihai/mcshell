import QtQuick
import qs.Config

// Launcher button — three straight vertical bars, each stepped up-right so
// the group reads as a right-leaning slash while the bars themselves remain
// upright. Colors pull from the theme palette.
Item {
    id: root

    signal clicked()

    property int size: Theme.iconSize

    implicitWidth: size
    implicitHeight: size

    Item {
        id: stack
        anchors.centerIn: parent
        width: root.size
        height: root.size
        opacity: mouse.containsMouse ? 1.0 : 0.9
        scale:   mouse.containsMouse ? 1.1 : 1.0

        // MSAA so the rotated bar edges don't stair-step.
        layer.enabled: true
        layer.smooth: true
        layer.samples: 4

        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        Behavior on scale   { NumberAnimation { duration: Theme.animFast } }

        readonly property real barW: 2.5
        readonly property real barH: root.size * 0.6
        readonly property real stepX: 3.5
        readonly property real stepY: 2.5
        readonly property real barTilt: 18

        Repeater {
            model: [
                { color: Theme.accent,    step: -1 },
                { color: Theme.tertiary,  step:  0 },
                { color: Theme.red,       step:  1 }
            ]
            Rectangle {
                width: stack.barW
                height: stack.barH
                color: modelData.color
                antialiasing: true
                rotation: stack.barTilt
                x: stack.width  / 2 + stack.stepX * 1.5 * modelData.step - width  / 2
                y: stack.height / 2 - stack.stepY       * modelData.step - height / 2
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        // First-click grab workaround: on bar startup the initial press gets
        // canceled before release. Firing click on cancel preserves the action.
        onCanceled: root.clicked()
    }
}
