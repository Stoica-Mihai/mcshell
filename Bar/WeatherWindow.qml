import QtQuick
import qs.Config

// Weather dropdown window — uses shared BarPopupWindow for chrome/focus/animation.
BarPopupWindow {
    id: root

    property var weather: null  // Bar/Weather.qml instance

    cardHeight: weatherContent.fullHeight
    wantsKeyboardFocus: true
    layershellNamespace: "mcshell-weather"

    WeatherPopup {
        id: weatherContent
        anchors.fill: parent
        weather: root.weather
    }
}
