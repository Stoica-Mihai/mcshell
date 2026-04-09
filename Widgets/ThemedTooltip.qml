import QtQuick
import qs.Config

// Themed tooltip that fades in after a delay when `showWhen` is true.
// Anchors below the parent, centered horizontally.
Rectangle {
    id: root

    property bool showWhen: false
    property alias text: label.text

    visible: opacity > 0
    opacity: showWhen && !_delay.running ? 1 : 0
    anchors.top: parent.bottom
    anchors.topMargin: Theme.spacingSmall
    anchors.horizontalCenter: parent.horizontalCenter
    width: label.implicitWidth + Theme.spacingMedium * 2
    height: label.implicitHeight + Theme.spacingSmall * 2
    radius: Theme.radiusSmall
    color: Theme.surfaceContainer
    border.width: 1
    border.color: Theme.outlineVariant

    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

    Text {
        id: label
        anchors.centerIn: parent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.fgDim
    }

    Timer {
        id: _delay
        interval: Theme.animCarousel
        running: root.showWhen
    }
}
