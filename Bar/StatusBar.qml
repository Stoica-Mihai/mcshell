import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Widgets
import qs.QuickSettings
import qs.NotificationHistory

Scope {
    id: root

    property string screenName: ""
    property var screen: null
    property bool hasPopup: qsPanel.isOpen || clock.popupVisible || sysTray.menuVisible || media.popupVisible || notifPanel.isOpen || volume.popupVisible

    property int unreadNotifications: 0
    property bool doNotDisturb: false
    signal dndToggled()
    property var notifHistoryModel: null
    signal launcherRequested()
    signal notifRemoved(string nid)
    signal notifCleared()
    signal notifPanelOpened()

    function dismissPopups() {
        qsPanel.close();
        clock.dismissPopup();
        sysTray.dismissMenu();
        media.dismissPopup();
        notifPanel.close();
        volume.dismissPopup();
    }

    // Fullscreen transparent click-catcher to dismiss popups
    PanelWindow {
        id: clickCatcher

        screen: root.screen
        visible: root.hasPopup
        color: "transparent"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        WlrLayershell.namespace: "mcshell-dismiss"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        MouseArea {
            anchors.fill: parent
            onClicked: root.dismissPopups()
        }
    }

    PanelWindow {
        id: bar

        screen: root.screen

        anchors {
            top: true
            left: true
            right: true
        }

        margins {
            top: Theme.barMargin
            left: Theme.barMargin + 1
            right: Theme.barMargin + 1
        }

        implicitHeight: Theme.barHeight
        color: "transparent"
        exclusiveZone: Theme.barHeight + Theme.barMargin * 2

        WlrLayershell.namespace: "mcshell"
        WlrLayershell.layer: WlrLayer.Top

        Rectangle {
            anchors.fill: parent
            radius: Theme.barRadius
            color: Theme.bg
            border.width: 1
            border.color: Theme.border

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 0

                // Left: launcher button + workspaces + window title
                IconButton {
                    icon: Theme.iconSearch
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: 10
                    onClicked: root.launcherRequested()
                }

                Workspaces {
                    Layout.alignment: Qt.AlignVCenter
                    screenName: root.screenName
                }

                ActiveWindow {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 10
                    Layout.maximumWidth: 300
                }

                Item { Layout.fillWidth: true }

                // Center: clock
                Clock {
                    id: clock
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                // Right: media, network, volume, tray
                RowLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Theme.itemSpacing

                    Media {
                        id: media
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Volume {
                        id: volume
                        Layout.alignment: Qt.AlignVCenter
                    }

                    SysTray {
                        id: sysTray
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Notification bell
                    Item {
                        id: bellButton
                        Layout.preferredWidth: Theme.iconSize
                        Layout.preferredHeight: Theme.iconSize
                        Layout.alignment: Qt.AlignVCenter

                        Item {
                            anchors.fill: parent

                            Text {
                                anchors.centerIn: parent
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.iconSize
                                color: bellMouse.containsMouse ? Theme.accent
                                     : root.doNotDisturb ? Theme.fgDim
                                     : root.unreadNotifications > 0 ? Theme.accent
                                     : Theme.fg
                                text: root.doNotDisturb ? Theme.iconDndOn : Theme.iconBell

                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            MouseArea {
                                id: bellMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                onClicked: event => {
                                    if (event.button === Qt.MiddleButton) {
                                        root.dndToggled();
                                    } else {
                                        if (notifPanel.isOpen)
                                            notifPanel.close();
                                        else
                                            notifPanel.showAt(bellButton);
                                    }
                                }
                            }
                        }

                        // Unread count badge
                        Rectangle {
                            visible: root.unreadNotifications > 0 && !root.doNotDisturb
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: -3
                            anchors.rightMargin: -5
                            width: Math.max(14, badgeText.implicitWidth + 6)
                            height: 14
                            radius: 7
                            color: Theme.red

                            Text {
                                id: badgeText
                                anchors.centerIn: parent
                                text: root.unreadNotifications > 99 ? "99+" : root.unreadNotifications
                                color: Theme.bgSolid
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.bold: true
                            }
                        }

                        NotificationHistory {
                            id: notifPanel
                            historyModel: root.notifHistoryModel
                            onRemoveFromHistory: nid => root.notifRemoved(nid)
                            onClearAllHistory: root.notifCleared()
                            onIsOpenChanged: {
                                if (isOpen) root.notifPanelOpened();
                            }
                        }
                    }

                    // Quick settings button
                    IconButton {
                        id: qsButton
                        icon: Theme.iconSettings
                        Layout.alignment: Qt.AlignVCenter
                        onClicked: {
                            if (qsPanel.isOpen)
                                qsPanel.close();
                            else
                                qsPanel.showAt(qsButton);
                        }

                        QuickSettingsPanel {
                            id: qsPanel
                        }
                    }
                }
            }
        }
    }
}
