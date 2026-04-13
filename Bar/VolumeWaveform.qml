import QtQuick
import qs.Config
import qs.Widgets

// Volume waveform — ascending bars scaled by volume level.
// Hover tooltip shows the percentage. Same footprint as the CPU waveform.
Item {
    id: root

    required property real rawVolume
    required property int volume
    required property bool muted

    signal clicked(var event)
    signal wheel(var event)

    property bool active: false
    readonly property bool hovered: mouse.containsMouse

    implicitWidth: bars.implicitWidth
    implicitHeight: Theme.iconSize

    Row {
        id: bars
        anchors.centerIn: parent
        spacing: 1.5

        Repeater {
            model: 8

            Rectangle {
                width: 2.5
                radius: 1
                anchors.bottom: parent.bottom

                // Each bar maps to a volume segment. Bar 0 fills at 0-12.5%,
                // bar 1 at 12.5-25%, etc. Within its segment, height ramps 2→14.
                readonly property real _threshold: index / 8
                readonly property real _fill: Math.max(0, Math.min(1, (root.rawVolume - _threshold) * 8))

                height: Math.max(2, _fill * 10)
                color: root.muted ? Theme.fgDim : Theme.accent

                Behavior on height { NumberAnimation { duration: Theme.animCarousel; easing.type: Easing.OutCubic } }
                Behavior on color  { ColorAnimation  { duration: Theme.animFast } }
            }
        }
    }

    // Mute slash — diagonal line through the bars
    Rectangle {
        visible: root.muted
        anchors.centerIn: bars
        width: Math.sqrt(bars.implicitWidth * bars.implicitWidth + 14 * 14)
        height: 1.5
        radius: 1
        color: Theme.red
        rotation: -35
    }

    ActiveUnderline { visible: root.active }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: event => root.clicked(event)
        onWheel: event => root.wheel(event)
        onCanceled: root.clicked({ button: Qt.LeftButton })
    }

    ThemedTooltip {
        showWhen: root.hovered && !root.active
        text: root.muted ? "Muted" : root.volume + "%"
    }
}
