import QtQuick
import qs.Config

// 3-state toggle: left (0), center (1), right (2).
// Thumb snaps to positions with smooth animation.
// Click on track regions or use left/right to change state.
Item {
    id: root

    property int state: 0  // 0 = left, 1 = center, 2 = right
    property var labels: ["Off", "On", "Auto"]
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
            id: thumb
            width: root.thumbSize
            height: root.thumbSize
            radius: root.thumbSize / 2
            y: (parent.height - height) / 2
            x: root._thumbX
            color: root.colors[root.state] ?? Theme.accent

            Behavior on x { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Theme.animNormal } }
        }

        // Click zones — divide track into 3 regions
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                const third = width / 3;
                const newState = mouse.x < third ? 0 : mouse.x < third * 2 ? 1 : 2;
                if (newState !== root.state) {
                    root.state = newState;
                    root.changed(newState);
                }
            }
        }
    }

    // Keyboard: left/right to cycle
    function cycleForward() {
        if (state < 2) { state++; changed(state); }
    }
    function cycleBackward() {
        if (state > 0) { state--; changed(state); }
    }
}
