import QtQuick
import QtQuick.Window
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
    width: label.implicitWidth + Theme.spacingMedium * 2
    height: label.implicitHeight + Theme.spacingSmall * 2

    // Center on parent, but clamp to stay on-screen
    x: {
        const centered = (parent.width - width) / 2;
        const globalX = parent.mapToItem(null, centered, 0).x;
        const screenW = (Window.window?.width ?? 1920);
        if (globalX + width > screenW - 4) return centered - (globalX + width - screenW + 4);
        if (globalX < 4) return centered + (4 - globalX);
        return centered;
    }
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
