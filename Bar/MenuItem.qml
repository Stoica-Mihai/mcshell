import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Config

// Reusable menu item for tray context menus.
// Handles separators, labels, check indicators, submenu arrows, hover.
Item {
    id: root

    required property var modelData
    property bool showArrow: false

    signal triggered()

    implicitHeight: modelData?.isSeparator ? 9 : 28

    // Separator
    Rectangle {
        visible: root.modelData?.isSeparator ?? false
        anchors.centerIn: parent
        width: parent.width - 12
        height: 1
        color: Theme.border
    }

    // Menu item
    Rectangle {
        anchors.fill: parent
        visible: !(root.modelData?.isSeparator ?? false)
        radius: Theme.radiusTiny
        color: itemMouse.containsMouse ? Theme.bgHover : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: Theme.spacingSmall

            // Check indicator
            Text {
                visible: {
                    const bt = root.modelData?.buttonType ?? QsMenuButtonType.None;
                    return bt !== QsMenuButtonType.None;
                }
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSizeTiny
                color: Theme.accent
                text: {
                    const checked = root.modelData?.checkState === Qt.Checked
                                 || (root.modelData?.checked ?? false);
                    return checked ? Theme.iconCheck : " ";
                }
            }

            // Label
            Text {
                Layout.fillWidth: true
                text: root.modelData?.text ? root.modelData.text.replace(/[\n\r]+/g, " ") : ""
                color: (root.modelData?.enabled ?? true) ? Theme.fg : Theme.fgDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            // Submenu arrow
            Text {
                visible: root.modelData?.hasChildren ?? false
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSizeTiny
                color: Theme.fgDim
                text: Theme.iconChevronRight
            }
        }

        MouseArea {
            id: itemMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: (root.modelData?.enabled ?? true)
                  && !(root.modelData?.isSeparator ?? false)
            onClicked: root.triggered()
        }
    }
}
