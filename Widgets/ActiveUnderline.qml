import QtQuick
import qs.Config

// Accent underline indicator shown below active items (tabs, capsule items).
Rectangle {
    anchors.bottom: parent.bottom
    anchors.bottomMargin: -4
    anchors.horizontalCenter: parent.horizontalCenter
    width: parent.width + 4
    height: 2
    radius: 1
    color: Theme.accent
}
