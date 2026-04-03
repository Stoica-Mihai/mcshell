import QtQuick
import qs.Config

// 3-state toggle: left (0), center (1), right (2).
// Thumb snaps to positions with smooth animation.
// Display-only — state is driven by parent binding.
// Click emits changed() signal for parent to handle.
Item {
    id: root

    property int state: 0  // 0 = left, 1 = center, 2 = right
    property var colors: [Theme.fgDim, Theme.accent, Theme.green]

    property int trackWidth: 48
    property int trackHeight: 20
    property int thumbSize: 16

    signal changed(int newState)

    implicitWidth: trackWidth
    implicitHeight: trackHeight

    readonly property real _thumbX: {
        const travel = trackWidth - thumbSize - 4;
        return 2 + state * travel / 2;
    }

    // Track
    Rectangle {
        width: root.trackWidth
        height: root.trackHeight
        radius: root.trackHeight / 2
        color: Theme.overlay
        border.width: 1
        border.color: Theme.border
        anchors.verticalCenter: parent.verticalCenter

        // Thumb
        Rectangle {
            width: root.thumbSize
            height: root.thumbSize
            radius: root.thumbSize / 2
            y: (parent.height - height) / 2
            x: root._thumbX
            color: root.colors[root.state] ?? Theme.accent

            Behavior on x { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Theme.animNormal } }
        }

        // Click zones — emit signal, don't set state (parent binding owns it)
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                const third = width / 3;
                const newState = mouse.x < third ? 0 : mouse.x < third * 2 ? 1 : 2;
                if (newState !== root.state)
                    root.changed(newState);
            }
        }
    }
}
