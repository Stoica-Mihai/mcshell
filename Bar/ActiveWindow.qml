import QtQuick
import Quickshell.Niri
import qs.Config
import qs.Widgets

Item {
    id: root

    readonly property string title: Niri.focusedWindow?.title ?? ""
    readonly property string appId: Niri.focusedWindow?.appId ?? ""
    readonly property int windowId: Niri.focusedWindow?.id ?? -1

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight
    visible: title !== ""

    InfiniteText {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, 300)
        text: root.title
        font.pixelSize: Theme.fontSizeSmall
        onClicked: {
            if (root.windowId >= 0)
                Niri.dispatch(["focus-window", "--id", root.windowId.toString()]);
        }
    }
}
