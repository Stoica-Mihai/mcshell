import QtQuick
import qs.Config

// Parallelogram two-state toggle. Display-only — state is owned by the
// parent binding. Emits `toggled(bool newState)` on click.
Item {
    id: root

    property bool checked: false
    property int trackWidth: 34
    property int trackHeight: 16
    property int thumbMargin: 2
    readonly property int thumbWidth: trackHeight - thumbMargin

    signal toggled(bool newState)

    implicitWidth: trackWidth
    implicitHeight: trackHeight

    // Track
    SkewRect {
        anchors.fill: parent
        fillColor: root.checked ? Theme.accent : Theme.overlay
        strokeColor: Theme.withAlpha(Theme.fg, 0.08)
        strokeWidth: 1

        Behavior on fillColor { ColorAnimation { duration: Theme.animNormal } }
    }

    // Thumb — snaps left/right with animation
    SkewRect {
        id: thumb
        width: root.thumbWidth
        height: root.trackHeight - root.thumbMargin * 2
        y: root.thumbMargin
        x: root.checked
            ? root.trackWidth - root.thumbWidth - root.thumbMargin
            : root.thumbMargin
        fillColor: root.checked ? Theme.accentFg : Theme.fg

        Behavior on x { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
        Behavior on fillColor { ColorAnimation { duration: Theme.animNormal } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
