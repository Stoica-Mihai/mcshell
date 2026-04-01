import QtQuick
import QtQuick.Layouts
import Quickshell.Niri
import qs.Config

Item {
    id: root

    property string screenName: ""

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // Reactive workspace list — filtered by screen, sorted by index
    readonly property var workspaces: {
        const all = Niri.workspaces.values;
        const filtered = [];
        for (let i = 0; i < all.length; i++) {
            if (all[i].output === root.screenName)
                filtered.push(all[i]);
        }
        filtered.sort((a, b) => a.idx - b.idx);
        return filtered;
    }

    MouseArea {
        anchors.fill: row
        onWheel: wheel => {
            Niri.dispatch(wheel.angleDelta.y > 0
                ? ["focus-workspace-up"]
                : ["focus-workspace-down"]);
        }
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

                property bool focused: modelData.focused
                property bool occupied: modelData.occupied

                implicitWidth: focused ? 22 : 8
                implicitHeight: 8
                radius: 4

                color: modelData.urgent ? Theme.red
                     : focused          ? Theme.accent
                     : occupied         ? Theme.fgDim
                     :                    Qt.rgba(1, 1, 1, 0.12)

                Behavior on implicitWidth {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Niri.dispatch(["focus-workspace", pill.modelData.idx.toString()])
                }
            }
        }
    }
}
