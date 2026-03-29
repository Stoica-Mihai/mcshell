import QtQuick
import Quickshell.Io
import qs.Config
import qs.Widgets

Item {
    id: root

    property string title: ""
    property string appId: ""
    property int windowId: -1

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight
    visible: title !== ""

    PolledProcess {
        command: ["niri", "msg", "-j", "focused-window"]
        interval: 250
        onRead: data => {
            try {
                const win = JSON.parse(data);
                root.title = win.title || "";
                root.appId = win.app_id || "";
                root.windowId = win.id ?? -1;
            } catch (e) {
                root.title = "";
                root.appId = "";
            }
        }
    }

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
                    focusWindow.running = true;
            }
        }
    }

    Process {
        id: focusWindow
        command: ["niri", "msg", "action", "focus-window", "--id", "" + root.windowId]
    }
}
