import QtQuick
import qs.Config

BarPopupWindow {
    id: root

    cardHeight: configContent.fullHeight
    wantsKeyboardFocus: true
    namespace: "mcshell-sysinfo-settings"

    SysInfoSettingsPopup {
        id: configContent
        anchors.fill: parent
        windowOpen: root.isOpen
    }
}
