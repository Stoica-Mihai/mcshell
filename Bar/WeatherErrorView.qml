import QtQuick
import QtQuick.Layouts
import qs.Config

// Weather popup "error" view: failure icon + message + retry affordance.
ColumnLayout {
    id: root

    required property var weather
    signal requestEdit()

    Layout.alignment: Qt.AlignHCenter
    Layout.fillWidth: true
    spacing: Theme.spacingNormal

    Item { Layout.preferredHeight: Theme.spacingSmall }

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: Theme.iconWeatherError
        font.family: Theme.iconFont
        font.pixelSize: 32
        color: Theme.red
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: "Could not load weather"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        color: Theme.fg
        font.weight: Font.Medium
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        text: (root.weather?.errorMsg ?? "") + "\nCheck your location or network"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.fgDim
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: "Click here to change location"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.accent

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.requestEdit()
        }
    }

    Item { Layout.preferredHeight: Theme.spacingSmall }
}
