import QtQuick
import qs.Config

// Skewed-morphism slider — parallelogram track + parallelogram knob + a
// short tick mark dropping below the knob to mark the current value.
// Set `value` (0..1) and bind `onMoved(real newValue)` to apply changes.
Item {
    id: root

    property real value: 0
    property color accentColor: Theme.accent
    property color knobColor: Theme.fg
    property int trackHeight: 6
    property int knobSize: 14
    property real step: Theme.volumeStep

    property real skewAmount: -0.3

    signal moved(real newValue)

    readonly property bool dragging: sliderMouse.pressed

    height: knobSize + 6

    SkewRect {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.trackHeight
        skewAmount: root.skewAmount
        fillColor: Theme.overlayHover
        strokeColor: Theme.withAlpha(Theme.fg, 0.08)
        strokeWidth: 1
    }

    SkewRect {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, Math.min(parent.width, parent.width * root.value))
        height: root.trackHeight
        skewAmount: root.skewAmount
        fillColor: root.accentColor
        Behavior on width { NumberAnimation { duration: Theme.animSlider } }
    }

    SkewRect {
        id: knob
        width: root.knobSize
        height: root.knobSize
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(0, Math.min(parent.width - width, (parent.width - width) * root.value))
        skewAmount: root.skewAmount
        fillColor: root.knobColor
        strokeColor: root.accentColor
        strokeWidth: 1

        Behavior on x {
            enabled: !sliderMouse.pressed
            NumberAnimation { duration: Theme.animSlider }
        }
    }

    Rectangle {
        anchors.top: knob.bottom
        anchors.topMargin: 1
        x: knob.x + knob.width / 2 - width / 2
        width: 1
        height: 4
        color: root.accentColor
    }

    MouseArea {
        id: sliderMouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onPressed: mouse => {
            root.moved(Math.max(0, Math.min(1, mouse.x / width)));
        }
        onPositionChanged: mouse => {
            if (pressed)
                root.moved(Math.max(0, Math.min(1, mouse.x / width)));
        }
        onWheel: wheel => {
            if (wheel.angleDelta.y > 0)
                root.moved(Math.min(1, root.value + root.step));
            else
                root.moved(Math.max(0, root.value - root.step));
        }
    }
}
