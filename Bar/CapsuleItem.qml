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
    property bool alert: false
    property bool enabled_: false
    property bool connected: false
    property bool active: false

    signal clicked(var event)
    signal wheel(var event)

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    readonly property bool hovered: mouse.containsMouse
    readonly property color activeColor: alert ? Theme.red
                                       : connected ? Theme.cyan
                                       : enabled_ ? Theme.green
                                       : hovered ? Theme.accent
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
                anchors.topMargin: -2
                anchors.rightMargin: -4
                width: Math.max(12, badgeLabel.implicitWidth + 4)
                height: 12
                radius: 6
                color: Theme.accent
                z: 10

                Text {
                    id: badgeLabel
                    anchors.centerIn: parent
                    text: root.badge > 99 ? "99+" : root.badge
                    color: Theme.accentFg
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
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

    // Underline when panel is active
    ActiveUnderline { visible: root.active }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: event => root.clicked(event)
        onWheel: event => root.wheel(event)
        // Wayland layer-shell can cancel the first pointer grab after
        // startup (input region settling). Re-emit as a left click.
        onCanceled: root.clicked({ button: Qt.LeftButton })
    }
}
