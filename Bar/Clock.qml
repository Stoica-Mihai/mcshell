import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Config

Item {
    id: root

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    property alias currentDate: clock.date
    property bool popupVisible: calendarPopup.isOpen

    function dismissPopup() {
        calendarPopup.close();
    }

    function togglePopup() {
        if (calendarPopup.isOpen) {
            calendarPopup.close();
        } else {
            calendarPopup.viewDate = new Date();
            calendarPopup.viewMode = "days";
            calendarPopup.open();
        }
    }

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
        text: Qt.formatDateTime(clock.date, "ddd d MMM  HH:mm:ss")
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (calendarPopup.isOpen)
                calendarPopup.close();
            else {
                calendarPopup.viewDate = new Date();
                calendarPopup.viewMode = "days";
                calendarPopup.open();
            }
        }
    }

    CalendarPopup {
        id: calendarPopup
        currentDate: root.currentDate
        anchor.item: root
        anchor.rect.x: -(implicitWidth / 2 - root.width / 2)
    }
}
