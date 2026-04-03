import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.Config

Item {
    id: root

    implicitWidth: trayRow.implicitWidth
    implicitHeight: trayRow.implicitHeight

    property bool menuVisible: trayMenu.visible

    function dismissMenu() {
        trayMenu.close();
    }

    // Shared context menu popup (reused for all tray items)
    TrayMenu {
        id: trayMenu
    }

    // Shared tooltip popup (reused for all tray items)
    PopupWindow {
        id: tooltip

        property string text: ""
        property var anchorItem: null

        visible: false
        color: "transparent"

        implicitWidth: tipText.implicitWidth + 14
        implicitHeight: tipText.implicitHeight + 8

        anchor.item: anchorItem
        anchor.rect.x: anchorItem ? -(implicitWidth / 2 - anchorItem.width / 2) : 0
        anchor.rect.y: anchorItem ? anchorItem.height + 6 : 0

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusTiny
            color: Theme.bgSolid
            border.width: 1
            border.color: Theme.border

            Text {
                id: tipText
                anchors.centerIn: parent
                text: tooltip.text
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    RowLayout {
        id: trayRow
        spacing: Theme.spacingNormal

        Repeater {
            model: SystemTray.items

            Item {
                id: trayIcon
                required property SystemTrayItem modelData

                implicitWidth: Theme.iconSize
                implicitHeight: Theme.iconSize
                Layout.alignment: Qt.AlignVCenter

                opacity: trayMouse.containsMouse ? 1.0 : 0.8

                Behavior on opacity {
                    NumberAnimation { duration: Theme.animFast }
                }

                IconImage {
                    id: trayImg
                    width: Theme.iconSize
                    height: Theme.iconSize
                    anchors.centerIn: parent
                    asynchronous: true
                    backer.fillMode: Image.PreserveAspectFit
                    visible: false
                    source: {
                        const icon = modelData?.icon || "";
                        if (!icon) return "";
                        if (icon.includes("?path=")) {
                            const chunks = icon.split("?path=");
                            const path = chunks[1];
                            const name = chunks[0];
                            const fileName = name.substring(name.lastIndexOf("/") + 1);
                            return "file://" + path + "/" + fileName;
                        }
                        return icon;
                    }
                }

                // Colorize tray icons to match theme
                MultiEffect {
                    anchors.fill: trayImg
                    source: trayImg
                    colorization: 1.0
                    colorizationColor: Theme.fg
                }

                MouseArea {
                    id: trayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                    onContainsMouseChanged: {
                        if (containsMouse && !trayMenu.visible) {
                            tooltip.text = trayIcon.modelData.tooltipTitle
                                        || trayIcon.modelData.name
                                        || trayIcon.modelData.id
                                        || "";
                            tooltip.anchorItem = trayIcon;
                            tooltip.visible = true;
                        } else {
                            tooltip.visible = false;
                        }
                    }

                    onClicked: event => {
                        tooltip.visible = false;
                        if (event.button === Qt.RightButton) {
                            if (trayIcon.modelData.hasMenu) {
                                trayMenu.showMenu(trayIcon.modelData, trayIcon);
                            } else {
                                trayIcon.modelData.secondaryActivate();
                            }
                        } else if (event.button === Qt.MiddleButton) {
                            trayIcon.modelData.secondaryActivate();
                        } else {
                            if (trayIcon.modelData.onlyMenu && trayIcon.modelData.hasMenu) {
                                trayMenu.showMenu(trayIcon.modelData, trayIcon);
                            } else {
                                trayIcon.modelData.activate();
                            }
                        }
                    }
                }
            }
        }
    }
}
