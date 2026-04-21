import QtQuick
import qs.Config

BarPopupWindow {
    id: root

    cardHeight: configContent.fullHeight
    wantsKeyboardFocus: true
    namespace: Namespaces.sysInfoSettings

    SysInfoSettingsPopup {
        id: configContent
        anchors.fill: parent
        windowOpen: root.isOpen
    }
}
