import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs.Config
import qs.Widgets

AnimatedPopup {
    id: root

    property SystemTrayItem trayItem: null
    property var anchorItem: null
    property bool closing: false

    implicitWidth: 200
    fullHeight: Math.min(400, menuColumn.implicitHeight + 12)

    anchor.item: anchorItem
    anchor.rect.x: anchorItem ? Theme.centerAnchorX(implicitWidth, anchorItem.width) : 0

    function showMenu(item, anch) {
        if (closing) return;

        // Toggle: if same item, just close
        if (visible && trayItem === item) {
            close();
            return;
        }

        // Close submenu if open
        subMenu.visible = false;

        // Hide first, swap menu, then show — avoids accessing stale children
        visible = false;
        openFraction = 0;
        trayItem = item;
        anchorItem = anch;

        // Defer show to next frame so QsMenuOpener can rebuild
        openDelay.restart();
    }

    Timer {
        id: openDelay
        interval: 16
        onTriggered: root.open()
    }

    function close() {
        if (closing) return;
        closing = true;
        subMenu.visible = false;
        isOpen = false;
        openFraction = 0;
        visible = false;
        closing = false;
    }

    QsMenuOpener {
        id: opener
        menu: root.trayItem ? root.trayItem.menu : null
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 6
            contentHeight: menuColumn.implicitHeight
            clip: true

            ColumnLayout {
                id: menuColumn
                width: parent.width
                spacing: 0

                Repeater {
                    model: opener.children ? [...opener.children.values] : []

                    MenuItem {
                        id: entry
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight

                        onTriggered: {
                            if (!modelData) return;
                            if (modelData.hasChildren) {
                                subMenu.menuSource = modelData;
                                subMenu.anchorItem = entry;
                                subMenu.visible = !subMenu.visible;
                            } else {
                                modelData.triggered();
                                root.close();
                            }
                        }
                    }
                }
            }
        }

    // ── Static submenu popup (reused, never destroyed) ──────
    PopupWindow {
        id: subMenu

        property var menuSource: null
        property var anchorItem: null

        visible: false
        color: "transparent"
        implicitWidth: 200
        implicitHeight: Math.min(400, subColumn.implicitHeight + 12)

        anchor.item: anchorItem
        anchor.rect.x: anchorItem ? anchorItem.width + 4 : 0
        anchor.rect.y: 0

        QsMenuOpener {
            id: subOpener
            menu: subMenu.menuSource
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusMedium
            color: Theme.bgSolid
            border.width: 1
            border.color: Theme.border

            Flickable {
                anchors.fill: parent
                anchors.margins: 6
                contentHeight: subColumn.implicitHeight
                clip: true

                ColumnLayout {
                    id: subColumn
                    width: parent.width
                    spacing: 0

                    Repeater {
                        model: subOpener.children ? [...subOpener.children.values] : []

                        MenuItem {
                            Layout.fillWidth: true
                            Layout.preferredHeight: implicitHeight

                            onTriggered: {
                                if (!modelData) return;
                                modelData.triggered();
                                subMenu.visible = false;
                                root.close();
                            }
                        }
                    }
                }
            }
        }
    }
}
