import QtQuick
import QtQuick.Layouts
import qs.Config

// Reusable highlighted row for settings panels.
// Place icon, label, controls as children — they go into the inner RowLayout.
// Use the inline sub-components (Icon / Label / Value) to keep themed
// typography DRY at call sites.
Rectangle {
    id: root

    property bool selected: false
    property color selectedColor: Theme.overlay

    default property alias content: rowContent.data

    // Themed primitives for the three common row cells. Extra properties
    // can still be set on any instance (color overrides, fillWidth, etc.).
    component Icon: Text {
        font.family: Theme.iconFont
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.fgDim
    }
    component Label: Text {
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.fg
    }
    component Value: Text {
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeTiny
        color: Theme.fgDim
        horizontalAlignment: Text.AlignRight
    }

    Layout.fillWidth: true
    Layout.leftMargin: 4
    Layout.rightMargin: 4
    Layout.preferredHeight: 38
    radius: Theme.radiusSmall
    color: selected ? selectedColor : "transparent"

    RowLayout {
        id: rowContent
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingLarge
        anchors.rightMargin: Theme.spacingLarge
        spacing: Theme.spacingNormal
    }
}
