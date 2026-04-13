import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.Config

// Tray icon grid + inline context menu for the shared dropdown.
// Right-clicking a tray icon expands the panel to show the menu below the grid.
ColumnLayout {
    id: root

    spacing: 0

    // Active menu state
    property var activeTrayItem: null
    readonly property bool menuOpen: activeTrayItem !== null

    function openMenu(item) {
        activeTrayItem = null;  // reset to force rebind
        activeTrayItem = item;
    }

    function closeMenu() {
        activeTrayItem = null;
        traySubMenu.visible = false;
    }

    // ── Icon grid ────────────────────────────────────────
    GridLayout {
        id: grid
        Layout.alignment: Qt.AlignHCenter
        columns: Math.max(1, Math.min(5, SystemTray.items.values.length))
        rowSpacing: Theme.spacingNormal
        columnSpacing: Theme.spacingNormal

        Repeater {
            model: SystemTray.items

            Item {
                id: trayIcon
                required property SystemTrayItem modelData

                implicitWidth: 24
                implicitHeight: 24
                Layout.alignment: Qt.AlignCenter

                readonly property bool _isActive: root.activeTrayItem === modelData

                opacity: trayMouse.containsMouse || _isActive ? 1.0 : 0.8
                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

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

                MultiEffect {
                    anchors.fill: trayImg
                    source: trayImg
                    colorization: 1.0
                    colorizationColor: trayIcon._isActive ? Theme.accent : Theme.fg
                }

                MouseArea {
                    id: trayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                    onClicked: event => {
                        if (event.button === Qt.RightButton) {
                            if (trayIcon.modelData.hasMenu)
                                root.openMenu(trayIcon.modelData);
                            else
                                trayIcon.modelData.secondaryActivate();
                        } else if (event.button === Qt.MiddleButton) {
                            trayIcon.modelData.secondaryActivate();
                        } else {
                            if (trayIcon.modelData.onlyMenu && trayIcon.modelData.hasMenu)
                                root.openMenu(trayIcon.modelData);
                            else
                                trayIcon.modelData.activate();
                        }
                    }
                }
            }
        }
    }

    // ── Context menu (inline, below grid) ────────────────
    Rectangle {
        visible: root.menuOpen
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        Layout.topMargin: Theme.spacingNormal
        color: Theme.outlineVariant
    }

    QsMenuOpener {
        id: trayOpener
        menu: root.activeTrayItem ? root.activeTrayItem.menu : null
    }

    Flickable {
        visible: root.menuOpen
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(Theme.trayMenuMaxHeight, menuColumn.implicitHeight)
        Layout.topMargin: Theme.spacingSmall
        contentHeight: menuColumn.implicitHeight
        clip: true

        ColumnLayout {
            id: menuColumn
            width: parent.width
            spacing: 0

            Repeater {
                model: trayOpener.children ? [...trayOpener.children.values] : []

                MenuItem {
                    id: menuEntry
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight

                    onTriggered: {
                        if (!modelData) return;
                        if (modelData.hasChildren) {
                            traySubMenu.menuSource = modelData;
                            traySubMenu.anchorItem = menuEntry;
                            traySubMenu.visible = !traySubMenu.visible;
                        } else {
                            modelData.triggered();
                            root.closeMenu();
                        }
                    }
                }
            }
        }
    }

    // Submenu popup
    PopupWindow {
        id: traySubMenu
        property var menuSource: null
        property var anchorItem: null

        visible: false
        color: "transparent"
        implicitWidth: 200
        implicitHeight: Math.min(Theme.trayMenuMaxHeight, subColumn.implicitHeight + Theme.trayMenuPadding)

        anchor.item: anchorItem
        anchor.rect.x: anchorItem ? anchorItem.width + 4 : 0
        anchor.rect.y: 0

        QsMenuOpener {
            id: subOpener
            menu: traySubMenu.menuSource
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
                                traySubMenu.visible = false;
                                root.closeMenu();
                            }
                        }
                    }
                }
            }
        }
    }
}
