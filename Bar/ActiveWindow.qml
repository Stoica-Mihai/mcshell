import QtQuick
import Quickshell.Niri
import qs.Config

Item {
    id: root

    readonly property string title: Niri.focusedWindow?.title ?? ""
    readonly property string appId: Niri.focusedWindow?.appId ?? ""
    readonly property int windowId: Niri.focusedWindow?.id ?? -1

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight
    visible: title !== ""

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, 300)
        text: root.title
        color: titleMouse.containsMouse ? Theme.accent : Theme.fgDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        elide: Text.ElideRight

        Behavior on color { ColorAnimation { duration: 100 } }

        MouseArea {
            id: titleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.windowId >= 0)
                    Niri.dispatch(["focus-window", "--id", root.windowId.toString()]);
            }
        }
    }
}
