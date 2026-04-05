import QtQuick
import QtQuick.Layouts
import qs.Config

// 1px horizontal divider line.
Rectangle {
    property int topMargin: 0

    Layout.fillWidth: true
    Layout.preferredHeight: 1
    Layout.topMargin: topMargin
    color: Theme.outlineVariant
}
