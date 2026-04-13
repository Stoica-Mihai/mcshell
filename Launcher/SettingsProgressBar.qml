import QtQuick
import QtQuick.Layouts
import qs.Config

// Read-only progress bar for settings panels (brightness, volume, temperature).
// For interactive sliders with knob/drag, use Widgets/ControlSlider instead.
Rectangle {
    property real value: 0        // 0.0 to 1.0
    property color barColor: Theme.accent

    Layout.fillWidth: true
    height: 4
    radius: 2
    color: Theme.overlay

    Rectangle {
        width: parent.width * root.value
        height: parent.height
        radius: parent.radius
        color: root.barColor
    }
}
