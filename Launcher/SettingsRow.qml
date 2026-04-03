import QtQuick
import QtQuick.Layouts
import qs.Config

// Reusable highlighted row for settings panels.
// Place icon, label, controls as children — they go into the inner RowLayout.
Rectangle {
    id: root

    property bool selected: false
    property color selectedColor: Theme.overlay

    default property alias content: rowContent.data

    Layout.fillWidth: true
    Layout.leftMargin: 4
    Layout.rightMargin: 4
    Layout.preferredHeight: 38
    radius: Theme.radiusSmall
    color: selected ? selectedColor : "transparent"

    RowLayout {
        id: rowContent
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: Theme.spacingNormal
    }
}
