import QtQuick
import Quickshell
import qs.Config

Item {
    id: root

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    property alias currentDate: clock.date
    property bool popupVisible: false

    signal togglePopup()
    signal dismissPopup()

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.weight: Font.Medium
        text: Qt.formatDateTime(clock.date, "ddd d MMM yyyy  HH:mm:ss")
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.togglePopup()
    }
}
