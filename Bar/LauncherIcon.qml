import QtQuick
import qs.Config
import qs.Widgets

// Launcher button — wraps the shared McshellLogo widget with hover scale
// + a click signal so it can drive the launcher panel from the bar.
Item {
    id: root

    signal clicked()

    property int size: Theme.iconSize

    implicitWidth: size
    implicitHeight: size

    McshellLogo {
        id: logo
        anchors.centerIn: parent
        size: root.size
        opacity: mouse.containsMouse ? 1.0 : 0.9
        scale:   mouse.containsMouse ? 1.1 : 1.0

        // MSAA — the rotated bar edges stair-step at this larger bar size
        // without it; the notification-header instance can skip the FBO.
        layer.enabled: true
        layer.smooth: true
        layer.samples: 4

        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        Behavior on scale   { NumberAnimation { duration: Theme.animFast } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        // First-click grab workaround: on bar startup the initial press gets
        // canceled before release. Firing click on cancel preserves the action.
        onCanceled: root.clicked()
    }
}
