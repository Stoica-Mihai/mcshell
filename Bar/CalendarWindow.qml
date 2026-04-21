import QtQuick
import qs.Config

// Calendar dropdown window — uses shared BarPopupWindow for chrome/animation.
// wantsKeyboardFocus: true so Escape dismisses the popup. While open, the
// calendar grabs keyboard focus from the underlying app; outside-click or
// Escape releases it.
BarPopupWindow {
    id: root

    property var currentDate: new Date()

    cardHeight: calendarContent.fullHeight
    wantsKeyboardFocus: true
    namespace: Namespaces.calendar

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
