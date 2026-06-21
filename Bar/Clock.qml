import QtQuick
import qs.Config
import qs.Core

// Clock view — time comes from the shared Core/ClockService singleton (one
// SystemClock for the whole shell, not one per bar).
Item {
    id: root

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    property bool popupVisible: false

    signal togglePopup()
    signal toggleConfigPopup()
    signal dismissPopup()

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.weight: Font.Medium
        text: ClockService.date.toLocaleString(Qt.locale(), UserSettings.clockFormatString)
    }

    BarClickArea {
        anchors.fill: parent
        onLeftClicked:  root.togglePopup()
        onRightClicked: root.toggleConfigPopup()
    }
}
