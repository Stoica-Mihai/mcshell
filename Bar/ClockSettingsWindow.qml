import QtQuick
import qs.Config

BarPopupWindow {
    id: root

    cardHeight: configContent.fullHeight
    wantsKeyboardFocus: true
    namespace: Namespaces.clockSettings

    ClockSettingsPopup {
        id: configContent
        anchors.fill: parent
        windowOpen: root.isOpen
    }
}
