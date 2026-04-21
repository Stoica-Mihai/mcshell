import QtQuick
import qs.Config

// Weather dropdown window — uses shared BarPopupWindow for chrome/focus/animation.
BarPopupWindow {
    id: root

    property var weather: null  // Bar/Weather.qml instance

    cardHeight: weatherContent.fullHeight
    wantsKeyboardFocus: true
    layershellNamespace: "mcshell-weather"

    function toggleEdit() {
        if (isOpen) {
            close();
        } else {
            weatherContent.editMode = true;
            open();
        }
    }

    // Left-click handler — mirrors the Clock/Calendar vs Clock/Settings pattern:
    // if the edit view is currently showing, swap to the loaded view instead
    // of closing so the user can go straight from editing to the forecast.
    function togglePreview() {
        if (isOpen && weatherContent.editMode) {
            weatherContent.editMode = false;
        } else {
            if (!isOpen) weatherContent.editMode = false;
            toggle();
        }
    }

    WeatherPopup {
        id: weatherContent
        anchors.fill: parent
        weather: root.weather
        windowOpen: root.isOpen
    }
}
