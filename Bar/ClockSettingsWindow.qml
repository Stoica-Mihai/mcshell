import QtQuick
import qs.Config

BarPopupWindow {
    id: root

    cardHeight: configContent.fullHeight
    wantsKeyboardFocus: true
    layershellNamespace: "mcshell-clock-settings"

    ClockSettingsPopup {
        id: configContent
        anchors.fill: parent
        windowOpen: root.isOpen
    }
}
