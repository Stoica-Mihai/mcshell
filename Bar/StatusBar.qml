import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Widgets
import qs.QuickSettings

Scope {
    id: root

    property string screenName: ""
    property var screen: null
    property bool hasPopup: qsPanel.isOpen || clock.popupVisible || sysTray.menuVisible

    signal launcherRequested()

    function dismissPopups() {
        qsPanel.close();
        clock.dismissPopup();
        sysTray.dismissMenu();
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
                    icon: "\uf002"
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
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Volume {
                        Layout.alignment: Qt.AlignVCenter
                    }

                    SysTray {
                        id: sysTray
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Quick settings button
                    IconButton {
                        id: qsButton
                        icon: "\uf013"
                        Layout.alignment: Qt.AlignVCenter
                        onClicked: {
                            if (qsPanel.isOpen)
                                qsPanel.close();
                            else
                                qsPanel.open(qsButton);
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
