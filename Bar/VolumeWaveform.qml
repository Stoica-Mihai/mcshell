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

    signal leftClicked()
    signal rightClicked()
    signal middleClicked()
    signal wheel(var event)

    property bool active: false
    readonly property bool hovered: mouse.containsMouse

    implicitWidth: bars.implicitWidth
    implicitHeight: Theme.iconSize

    WaveformBars {
        id: bars
        anchors.centerIn: parent

        // Each bar maps to a volume segment. Bar 0 fills at 0-12.5%,
        // bar 1 at 12.5-25%, etc. Within its segment, height ramps 2→14.
        barHeight: function(i) {
            const threshold = i / 8;
            const fill = Math.max(0, Math.min(1, (root.rawVolume - threshold) * 8));
            return fill * 10;
        }
        barColor: function() { return root.muted ? Theme.fgDim : Theme.accent; }
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

    BarClickArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onLeftClicked:   root.leftClicked()
        onRightClicked:  root.rightClicked()
        onMiddleClicked: root.middleClicked()
        onWheel: event => root.wheel(event)
    }

    ThemedTooltip {
        showWhen: root.hovered && !root.active
        text: root.muted ? "Muted" : root.volume + "%"
    }
}
