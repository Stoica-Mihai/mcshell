import QtQuick
import QtQuick.Controls
import qs.Config

// Themed vertical scrollbar with configurable width.
ScrollBar {
    property int barWidth: 6

    policy: ScrollBar.AsNeeded
    width: barWidth

    contentItem: Rectangle {
        implicitWidth: barWidth
        radius: barWidth / 2
        color: Theme.fgDim
        opacity: Theme.opacityDim
    }
}
