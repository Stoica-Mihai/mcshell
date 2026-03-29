import QtQuick
import qs.Config

// Reusable slider track with knob, click-to-set, drag, and scroll.
// Set `value` (0.0–1.0), bind `onMoved(real newValue)` to apply changes.
Item {
    id: root

    // ── API ─────────────────────────────────────────────
    property real value: 0               // 0.0 to 1.0
    property color accentColor: Theme.accent
    property color knobColor: Theme.fg
    property int trackHeight: 6
    property int knobSize: 14
    property real step: 0.02             // scroll step

    signal moved(real newValue)

    // Expose drag state so parents can suppress polling
    readonly property bool dragging: sliderMouse.pressed

    height: 20

    // ── Track background ────────────────────────────────
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.trackHeight
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.12)

        // Fill
        Rectangle {
            width: Math.max(0, Math.min(parent.width, parent.width * root.value))
            height: parent.height
            radius: parent.radius
            color: root.accentColor

            Behavior on width { NumberAnimation { duration: 30 } }
        }
    }

    // ── Knob ────────────────────────────────────────────
    Rectangle {
        width: root.knobSize
        height: root.knobSize
        radius: root.knobSize / 2
        y: (parent.height - height) / 2
        x: Math.max(0, Math.min(parent.width - width, (parent.width - width) * root.value))
        color: root.knobColor

        Behavior on x {
            enabled: !sliderMouse.pressed
            NumberAnimation { duration: 30 }
        }
    }

    // ── Interaction ─────────────────────────────────────
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
