import QtQuick
import Quickshell.Niri
import qs.Config
import qs.Widgets

Item {
    id: root

    readonly property string title: Niri.focusedWindow?.title ?? ""
    readonly property int windowId: Niri.focusedWindow?.id ?? -1

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight
    visible: title !== ""
    // Never allow the title to paint outside whatever width the parent
    // (StatusBar's left segment) assigns us — the segment is a parallelogram
    // and spill-over shows across the diagonal edge.
    clip: true

    InfiniteText {
        id: label
        anchors.fill: parent
        text: root.title
        font.pixelSize: Theme.fontSizeSmall
        onClicked: {
            if (root.windowId >= 0)
                Niri.dispatch(["focus-window", "--id", root.windowId.toString()]);
        }
    }
}
