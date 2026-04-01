import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Widgets

PanelWindow {
    id: launcher

    // ── Public API ──────────────────────────────────────
    property bool isOpen: false
    signal notificationsViewed()
    property var notifHistoryModel: null  // set from shell.qml

    function open() {
        isOpen = true;
        visible = true;
        activeTab = 0;
        searchField.text = "";
        selectedIndex = 0;
        activeCategory.onSearch("");
        activeCategory.onTabEnter();
        searchField.forceActiveFocus();
    }

    function close() {
        isOpen = false;
        visible = false;
        searchField.text = "";
        for (let i = 0; i < categories.length; i++)
            categories[i].onTabLeave();
    }

    function toggle() {
        if (isOpen) close(); else open();
    }

    function openTab(tab) {
        if (!isOpen) {
            isOpen = true;
            visible = true;
            activeTab = tab;
            searchField.text = "";
            selectedIndex = 0;
            activeCategory.onSearch("");
            activeCategory.onTabEnter();
            searchField.forceActiveFocus();
        } else {
            switchTab(tab);
        }
    }

    function refocusSearch() {
        searchField.forceActiveFocus();
    }

    // ── Window setup ────────────────────────────────────
    visible: false
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.namespace: "mcshell-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    // ── Categories ──────────────────────────────────────
    property list<LauncherCategory> categories: [
        CategoryApps { launcher: launcher },
        CategoryClipboard { launcher: launcher },
        CategoryNotifications { launcher: launcher; notifHistoryModel: launcher.notifHistoryModel },
        CategoryWifi { launcher: launcher },
        CategoryBluetooth { launcher: launcher },
        CategorySettings { launcher: launcher }
    ]

    // ── Tab state ───────────────────────────────────────
    property int activeTab: 0
    readonly property int tabCount: categories.length
    readonly property var activeCategory: categories[activeTab]
    readonly property var currentList: activeCategory.model
    readonly property string searchText: searchField.text

    property int selectedIndex: 0

    // ── Carousel config ─────────────────────────────────
    readonly property int sideCount: 5
    readonly property real stripWidth: 80
    readonly property real expandedWidth: 500
    readonly property real carouselHeight: 350
    readonly property real stripSpacing: 6

    function navigate(delta) {
        if (currentList.length === 0) return;
        selectedIndex = Math.max(0, Math.min(currentList.length - 1, selectedIndex + delta));
    }

    function calcRowX() {
        if (currentList.length === 0) return carouselArea.width / 2;
        const firstVisible = Math.max(0, selectedIndex - sideCount);
        const visibleLeftCount = selectedIndex - firstVisible;
        const leftWidth = visibleLeftCount * (stripWidth + stripSpacing);
        const centerOffset = expandedWidth / 2;
        const collapsedCount = firstVisible;
        const collapsedWidth = collapsedCount * stripSpacing;
        return carouselArea.width / 2 - collapsedWidth - leftWidth - centerOffset;
    }

    // ── Tab switching ───────────────────────────────────
    function switchTab(tab) {
        if (tab < 0 || tab >= categories.length) return;
        if (activeTab === tab && isOpen) {
            // Already on this tab — just refresh
            searchField.text = "";
            selectedIndex = 0;
            activeCategory.onSearch("");
            searchField.forceActiveFocus();
            return;
        }
        activeCategory.onTabLeave();
        activeTab = tab;
        searchField.text = "";
        selectedIndex = 0;
        activeCategory.onSearch("");
        activeCategory.onTabEnter();
        searchField.forceActiveFocus();
    }

    // ── Activate selected item ──────────────────────────
    function activate() {
        if (selectedIndex < 0 || selectedIndex >= currentList.length) return;
        activeCategory.onActivate(selectedIndex);
    }

    // ── UI ──────────────────────────────────────────────

    // Backdrop
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        MouseArea { anchors.fill: parent; onClicked: launcher.close() }
    }

    // Search bar — fixed position above center
    Rectangle {
        id: searchBar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: carouselArea.top
        anchors.bottomMargin: 20
        width: Math.min(740, parent.width - 80)
        height: 44
            radius: 10
            color: Theme.bg
            border.width: 1
            border.color: Theme.border

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10

                // Tab buttons — driven by categories
                Repeater {
                    model: launcher.categories

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        Layout.preferredWidth: tabContent.implicitWidth + 16
                        Layout.preferredHeight: 28
                        radius: 6
                        color: launcher.activeTab === index ? Theme.accent : "transparent"

                        RowLayout {
                            id: tabContent
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: modelData.tabIcon
                                font.family: Theme.iconFont
                                font.pixelSize: 11
                                color: launcher.activeTab === index ? Theme.bgSolid : Theme.fgDim
                            }

                            Text {
                                text: modelData.tabLabel
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: launcher.activeTab === index ? Theme.bgSolid : Theme.fgDim
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: launcher.switchTab(index)
                        }
                    }
                }

                // Separator
                Rectangle { width: 1; Layout.preferredHeight: 20; color: Theme.border }

                // Search icon
                Text {
                    text: Theme.iconSearch
                    font.family: Theme.iconFont
                    font.pixelSize: 14
                    color: Theme.fgDim
                    Layout.alignment: Qt.AlignVCenter
                }

                TextInput {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    color: Theme.fg
                    clip: true
                    selectByMouse: true

                    onTextChanged: launcher.activeCategory.onSearch(text)

                    Keys.onPressed: event => {
                        // Category-first key dispatch
                        if (launcher.activeCategory.onKeyPressed(event)) {
                            event.accepted = true;
                            return;
                        }

                        switch (event.key) {
                        case Qt.Key_Escape: launcher.close(); event.accepted = true; break;
                        case Qt.Key_Left: launcher.navigate(-1); event.accepted = true; break;
                        case Qt.Key_Right: launcher.navigate(1); event.accepted = true; break;
                        case Qt.Key_Return:
                        case Qt.Key_Enter:
                            launcher.activate();
                            event.accepted = true;
                            break;
                        case Qt.Key_Tab:
                            launcher.switchTab((launcher.activeTab + 1) % launcher.tabCount);
                            event.accepted = true;
                            break;
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: launcher.activeCategory.searchPlaceholder
                        color: Theme.fgDim
                        font: parent.font
                        visible: !parent.text
                    }
                }
            }
        }

    // Carousel — centered on screen, fixed position
    Item {
            id: carouselArea
            anchors.centerIn: parent
            width: parent.width
            height: launcher.carouselHeight
            clip: true

            // Empty state — text for search/generic
            Text {
                anchors.centerIn: parent
                visible: launcher.currentList.length === 0
                      && searchField.text !== ""
                      && !launcher.activeCategory.disabledState
                text: "No results"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                color: Theme.fgDim
            }

            // Disabled state — generic (WiFi off, BT off)
            DisabledCard {
                visible: launcher.activeCategory.disabledState
                anchors.centerIn: parent
                width: launcher.expandedWidth
                height: launcher.carouselHeight
                icon: launcher.activeCategory.disabledIcon
                hint: launcher.activeCategory.disabledHint
            }

            // Scanning state — generic (WiFi scanning, BT scanning)
            DisabledCard {
                visible: launcher.activeCategory.scanningState
                      && !launcher.activeCategory.disabledState
                      && launcher.activeCategory.model.length === 0
                      && searchField.text === ""
                anchors.centerIn: parent
                width: launcher.expandedWidth
                height: launcher.carouselHeight
                icon: launcher.activeCategory.scanningIcon
                iconColor: Theme.accent
                iconOpacity: 0.3
                hint: launcher.activeCategory.scanningHint
            }

            // Sliding row — single generic Repeater
            Row {
                id: slidingRow
                x: launcher.calcRowX()
                height: launcher.carouselHeight
                spacing: launcher.stripSpacing
                visible: launcher.currentList.length > 0

                Behavior on x {
                    NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
                }

                Repeater {
                    model: launcher.activeCategory.model
                    delegate: launcher.activeCategory.cardDelegate
                }
            }

            // Navigation arrows
            IconButton {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                icon: Theme.iconArrowLeft
                size: 24
                normalColor: Theme.fgDim
                visible: launcher.selectedIndex > 0 && launcher.currentList.length > 0
                onClicked: launcher.navigate(-1)
            }

            IconButton {
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                icon: Theme.iconArrowRight
                size: 24
                normalColor: Theme.fgDim
                visible: launcher.selectedIndex < launcher.currentList.length - 1 && launcher.currentList.length > 0
                onClicked: launcher.navigate(1)
            }
        }

    // Footer — fixed position below carousel
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: carouselArea.bottom
        anchors.topMargin: 16
        visible: launcher.currentList.length > 0
              || launcher.activeCategory.disabledState
              || launcher.activeCategory.scanningState
        text: {
            // Disabled state — show toggle hint with shared suffix
            if (launcher.activeCategory.disabledState) {
                const hint = launcher.activeCategory.disabledLegendHint || launcher.activeCategory.legendHint;
                return hint + "  |  Tab switch  |  ESC close";
            }

            var t = ((launcher.selectedIndex + 1) + " / " + launcher.currentList.length)
                  + "  |  \u2190 \u2192 Navigate";
            if (launcher.activeCategory.legendHint)
                t += "  |  " + launcher.activeCategory.legendHint;
            t += "  |  Tab switch  |  ESC close";
            return t;
        }
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.fgDim
    }
}
