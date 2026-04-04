import QtQuick
import QtQuick.Layouts
import qs.Config

// 1px horizontal divider line using Theme.border.
Rectangle {
    property int topMargin: 0

    Layout.fillWidth: true
    Layout.preferredHeight: 1
    Layout.topMargin: topMargin
    color: Theme.border
}
