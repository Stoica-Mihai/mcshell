import QtQuick
import qs.Config
import qs.Widgets

// Reusable capsule indicator: icon + optional label with hover/alert coloring.
// Used in StatusBar's system capsule for volume, battery, etc.
Item {
    id: root

    property string icon: ""
    property string label: ""
    property int badge: 0
    property color badgeColor: Theme.accent
    property bool alert: false
    property bool enabled_: false
    property bool connected: false
    property bool highlight: false
    property bool active: false

    signal leftClicked()
    signal rightClicked()
    signal middleClicked()

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    readonly property bool hovered: mouse.containsMouse
    readonly property color activeColor: alert ? Theme.red
                                       : connected ? Theme.cyan
                                       : enabled_ ? Theme.green
                                       : (hovered || highlight) ? Theme.accent
                                       : Theme.fg

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        Item {
            width: Theme.iconSize
            height: Theme.iconSize

            Text {
                anchors.centerIn: parent
                font.family: Theme.iconFont
                font.pixelSize: Theme.iconSize
                color: root.activeColor
                text: root.icon
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            Rectangle {
                visible: root.badge > 0
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: -3
                anchors.rightMargin: -5
                width: Math.max(Theme.notifBadgeSize, badgeLabel.implicitWidth + 6)
                height: Theme.notifBadgeSize
                radius: Theme.notifBadgeSize / 2
                color: root.badgeColor
                z: 10

                Text {
                    id: badgeLabel
                    anchors.centerIn: parent
                    text: root.badge > 99 ? "99+" : root.badge
                    color: Theme.accentFg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMini
                    font.bold: true
                }
            }
        }

        Text {
            visible: root.label !== ""
            color: root.activeColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            text: root.label
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }
    }

    ActiveUnderline { visible: root.active }

    BarClickArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onLeftClicked:   root.leftClicked()
        onRightClicked:  root.rightClicked()
        onMiddleClicked: root.middleClicked()
    }
}
