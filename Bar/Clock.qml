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
    signal toggleConfigPopup()
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
        text: clock.date.toLocaleString(Qt.locale(), UserSettings.clockFormatString)
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.RightButton) root.toggleConfigPopup();
            else root.togglePopup();
        }
        onCanceled: root.togglePopup()
    }
}
