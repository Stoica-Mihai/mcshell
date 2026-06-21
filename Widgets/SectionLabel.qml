import QtQuick
import QtQuick.Layouts
import qs.Config

// Tiny section heading for settings panels and dropdowns — fgDim mini label
// with an optional accent tick before it.
RowLayout {
    id: root

    property string text: ""
    property bool tick: true

    Layout.fillWidth: true
    spacing: Theme.spacingSmall

    SkewRect {
        visible: root.tick
        implicitWidth: 10
        implicitHeight: 6
        fillColor: Theme.accent
        opacity: Theme.opacityBody
    }

    Text {
        text: root.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeMini
        color: Theme.fgDim
        Layout.fillWidth: true
    }
}
