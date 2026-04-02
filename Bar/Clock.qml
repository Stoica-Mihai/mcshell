import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Config

Item {
    id: root

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    property date currentDate: new Date()
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

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.currentDate = new Date()
    }

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.weight: Font.Medium
        text: root.currentDate.toLocaleDateString(Qt.locale(), "ddd d MMM") +
              "  " +
              root.currentDate.toLocaleTimeString(Qt.locale(), "HH:mm")
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
