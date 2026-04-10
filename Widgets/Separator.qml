import QtQuick
import QtQuick.Layouts
import qs.Config

// 1px horizontal divider line.
Rectangle {
    property int topMargin: 0
    property int leftMargin: 0
    property int rightMargin: 0

    Layout.fillWidth: true
    Layout.preferredHeight: 1
    Layout.topMargin: topMargin
    Layout.leftMargin: leftMargin
    Layout.rightMargin: rightMargin
    color: Theme.outlineVariant
}
