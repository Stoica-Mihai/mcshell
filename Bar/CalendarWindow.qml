import QtQuick
import qs.Config

// Calendar dropdown window — uses shared BarPopupWindow for chrome/animation.
// No keyboard focus needed (mouse-only date picker).
BarPopupWindow {
    id: root

    property var currentDate: new Date()

    cardHeight: calendarContent.fullHeight
    wantsKeyboardFocus: false
    layershellNamespace: "mcshell-calendar"

    // Reset view to current month each time it opens
    onIsOpenChanged: {
        if (isOpen) {
            calendarContent.viewDate = new Date();
            calendarContent.viewMode = "days";
        }
    }

    CalendarPopup {
        id: calendarContent
        anchors.fill: parent
        currentDate: root.currentDate
    }
}
