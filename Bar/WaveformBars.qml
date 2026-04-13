import QtQuick
import qs.Config

// Shared 8-bar waveform skeleton used by VolumeWaveform and SysWaveform.
// Callers provide barHeight(index) and barColor(index) callbacks.
Row {
    id: root

    property var barHeight: function(index) { return 2; }
    property var barColor: function(index) { return Theme.accent; }

    spacing: 1.5

    Repeater {
        model: 8

        Rectangle {
            width: 2.5
            radius: 1
            anchors.bottom: parent.bottom
            height: Math.max(2, root.barHeight(index))
            color: root.barColor(index)

            Behavior on height { NumberAnimation { duration: Theme.animCarousel; easing.type: Easing.OutCubic } }
            Behavior on color  { ColorAnimation  { duration: Theme.animCarousel } }
        }
    }
}
