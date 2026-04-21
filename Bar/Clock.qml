import QtQuick
import Quickshell
import qs.Config
import qs.Widgets

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
        precision: UserSettings.clockShowSeconds ? SystemClock.Seconds : SystemClock.Minutes
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

    BarClickArea {
        anchors.fill: parent
        onLeftClicked:  root.togglePopup()
        onRightClicked: root.toggleConfigPopup()
    }
}
