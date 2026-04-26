import QtQuick
import qs.Config

// mcshell logo — three vertical bars stepped up-right, each tinted from the
// active theme palette. Static visual only; for the bar's interactive
// launcher button, see Bar/LauncherIcon.qml which wraps this in a MouseArea.
Item {
    id: root

    property int size: Theme.iconSize

    implicitWidth: size
    implicitHeight: size

    // MSAA so the rotated bar edges don't stair-step on Wayland surfaces
    // that don't have multisample backing.
    layer.enabled: true
    layer.smooth: true
    layer.samples: 4

    readonly property real _barW: 2.5
    readonly property real _barH: size * 0.6
    readonly property real _stepX: 3.5
    readonly property real _stepY: 2.5
    readonly property real _barTilt: 18

    Repeater {
        model: [
            { color: Theme.accent,   step: -1 },
            { color: Theme.tertiary, step:  0 },
            { color: Theme.red,      step:  1 }
        ]
        Rectangle {
            width: root._barW
            height: root._barH
            color: modelData.color
            antialiasing: true
            rotation: root._barTilt
            x: root.width  / 2 + root._stepX * 1.5 * modelData.step - width  / 2
            y: root.height / 2 - root._stepY       * modelData.step - height / 2
        }
    }
}
