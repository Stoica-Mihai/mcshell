import QtQuick
import qs.Config
import qs.Widgets

// Reusable capsule indicator: icon + optional label with hover/alert coloring.
// Used in StatusBar's system capsule for volume, battery, etc.
Item {
    id: root

    property string icon: ""
    property string label: ""
    property bool alert: false
    property bool active: false

    signal clicked(var event)
    signal wheel(var event)

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    readonly property bool hovered: mouse.containsMouse
    readonly property color activeColor: alert ? Theme.red
                                       : hovered ? Theme.accent
                                       : Theme.fg

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        Text {
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSize
            color: root.activeColor
            text: root.icon
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
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
    }
}
