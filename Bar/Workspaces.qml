import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Config
import qs.Widgets

Item {
    id: root

    property string screenName: ""
    property var workspaces: []

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    PolledProcess {
        command: ["niri", "msg", "-j", "workspaces"]
        interval: 250
        onRead: data => {
            try {
                root.workspaces = JSON.parse(data)
                    .filter(ws => ws.output === root.screenName)
                    .sort((a, b) => a.idx - b.idx);
            } catch (e) {}
        }
    }

    MouseArea {
        anchors.fill: row
        onWheel: wheel => {
            if (wheel.angleDelta.y > 0)
                wsPrev.running = true;
            else
                wsNext.running = true;
        }
    }

    Process {
        id: wsPrev
        command: ["niri", "msg", "action", "focus-workspace-up"]
    }

    Process {
        id: wsNext
        command: ["niri", "msg", "action", "focus-workspace-down"]
    }

    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Repeater {
            model: root.workspaces

            Rectangle {
                id: pill
                required property var modelData

                property bool focused: modelData.is_focused
                property bool occupied: modelData.active_window_id !== null
                                     && modelData.active_window_id !== undefined

                implicitWidth: focused ? 22 : 8
                implicitHeight: 8
                radius: 4

                color: modelData.is_urgent ? Theme.red
                     : focused             ? Theme.accent
                     : occupied            ? Theme.fgDim
                     :                       Qt.rgba(1, 1, 1, 0.12)

                Behavior on implicitWidth {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: focusWs.running = true
                }

                Process {
                    id: focusWs
                    command: ["niri", "msg", "action", "focus-workspace", "" + pill.modelData.id]
                }
            }
        }
    }
}
