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
        editMode = false;
        searchField.text = "";
        selectedIndex = 0;
        activeCategory.onSearch("");
        activeCategory.onTabEnter();
        searchField.forceActiveFocus();
    }

    function close() {
        isOpen = false;
        visible = false;
        editMode = false;
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
            editMode = true;
            searchField.text = "";
            selectedIndex = 0;
            activeCategory.onSearch("");
            activeCategory.onTabEnter();
            searchField.forceActiveFocus();
        } else {
            switchTab(tab);
            editMode = true;
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
    signal wallpaperSelected(string path)

    property list<LauncherCategory> categories: [
        CategoryApps { launcher: launcher },
        CategoryClipboard { launcher: launcher },
        CategoryNotifications { launcher: launcher; notifHistoryModel: launcher.notifHistoryModel },
        CategoryWifi { launcher: launcher },
        CategoryBluetooth { launcher: launcher },
        CategoryWallpaper {
            launcher: launcher
            onWallpaperSelected: path => launcher.wallpaperSelected(path)
        },
        CategorySettings { launcher: launcher }
    ]

    // ── Tab state ───────────────────────────────────────
    property int activeTab: 0
    readonly property int tabCount: categories.length
    readonly property var activeCategory: categories[activeTab]
    readonly property var currentList: activeCategory.model
    readonly property int currentCount: carouselRepeater.count

    // Carousel model/delegate — reset together on tab switch to prevent
    // cross-contamination (new delegate rendering against old model data)
    property var _carouselModel: activeCategory.model
    property Component _carouselDelegate: activeCategory.cardDelegate
    readonly property string searchText: searchField.text

    property int selectedIndex: 0
    property bool editMode: false

    // ── Carousel config ─────────────────────────────────
    readonly property int sideCount: 5
    readonly property real stripWidth: 80
    readonly property real expandedWidth: 500
    readonly property real carouselHeight: 350
    readonly property real stripSpacing: 6

    function navigate(delta) {
        if (currentCount === 0) return;
        selectedIndex = Math.max(0, Math.min(currentCount - 1, selectedIndex + delta));
    }

    function calcRowX() {
        if (currentCount === 0) return carouselArea.width / 2;
        const visibleLeftCount = Math.min(selectedIndex, sideCount);
        const leftWidth = visibleLeftCount * (stripWidth + stripSpacing);
        const centerOffset = expandedWidth / 2;
        return carouselArea.width / 2 - leftWidth - centerOffset;
    }

    // ── Tab switching ───────────────────────────────────
    function switchTab(tab) {
        if (tab < 0 || tab >= categories.length) return;
        if (activeTab === tab && isOpen) {
            searchField.text = "";
            selectedIndex = 0;
            editMode = false;
            activeCategory.onSearch("");
            searchField.forceActiveFocus();
            return;
        }
        activeCategory.onTabLeave();
        editMode = false;
        // Clear carousel before switching — prevents delegate/model cross-contamination
        _carouselModel = [];
        _carouselDelegate = null;
        activeTab = tab;
        _carouselDelegate = activeCategory.cardDelegate;
        _carouselModel = Qt.binding(() => activeCategory.model);
        searchField.text = "";
        selectedIndex = 0;
        activeCategory.onSearch("");
        activeCategory.onTabEnter();
        searchField.forceActiveFocus();
    }

    // ── Activate selected item ──────────────────────────
    function activate() {
        if (selectedIndex < 0 || selectedIndex >= currentCount) return;
        activeCategory.onActivate(selectedIndex);
    }

    // ── UI ──────────────────────────────────────────────

    // Backdrop
    Rectangle {
        anchors.fill: parent
        color: Theme.backdrop
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
                        color: launcher.activeTab === index
                            ? (launcher.editMode ? Theme.bgHover : Theme.accent)
                            : "transparent"

                        Behavior on color { ColorAnimation { duration: Theme.animNormal } }

                        RowLayout {
                            id: tabContent
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: modelData.tabIcon
                                font.family: Theme.iconFont
                                font.pixelSize: 11
                                color: launcher.activeTab === index
                                    ? (launcher.editMode ? Theme.accent : Theme.bgSolid)
                                    : Theme.fgDim
                                Behavior on color { ColorAnimation { duration: Theme.animNormal } }
                            }

                            Text {
                                text: modelData.tabLabel
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: launcher.activeTab === index
                                    ? (launcher.editMode ? Theme.accent : Theme.bgSolid)
                                    : Theme.fgDim
                                Behavior on color { ColorAnimation { duration: Theme.animNormal } }
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

                    onTextChanged: {
                        launcher.selectedIndex = 0;
                        launcher.activeCategory.onSearch(text);
                        if (text !== "" && !launcher.editMode)
                            launcher.editMode = true;
                    }

                    Keys.onPressed: event => {
                        // Category-specific keys always get first chance
                        if (launcher.activeCategory.onKeyPressed(event)) {
                            event.accepted = true;
                            return;
                        }

                        if (!launcher.editMode) {
                            // Level 1: category browse — arrows switch categories
                            switch (event.key) {
                            case Qt.Key_Escape:
                                launcher.close();
                                event.accepted = true;
                                break;
                            case Qt.Key_Left:
                                launcher.switchTab((launcher.activeTab - 1 + launcher.tabCount) % launcher.tabCount);
                                event.accepted = true;
                                break;
                            case Qt.Key_Right:
                                launcher.switchTab((launcher.activeTab + 1) % launcher.tabCount);
                                event.accepted = true;
                                break;
                            case Qt.Key_Return:
                            case Qt.Key_Enter:
                            case Qt.Key_Down:
                                launcher.editMode = true;
                                event.accepted = true;
                                break;
                            }
                        } else {
                            // Level 2: inside category — arrows navigate items
                            switch (event.key) {
                            case Qt.Key_Escape:
                                launcher.editMode = false;
                                event.accepted = true;
                                break;
                            case Qt.Key_Left:
                                launcher.navigate(-1);
                                event.accepted = true;
                                break;
                            case Qt.Key_Right:
                                launcher.navigate(1);
                                event.accepted = true;
                                break;
                            case Qt.Key_Return:
                            case Qt.Key_Enter:
                                launcher.activate();
                                event.accepted = true;
                                break;
                            }
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
                visible: launcher.currentCount === 0
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
                      && launcher.currentCount === 0
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
                visible: launcher.currentCount > 0

                Behavior on x {
                    NumberAnimation { duration: Theme.animCarousel; easing.type: Easing.OutCubic }
                }

                Repeater {
                    id: carouselRepeater
                    model: launcher._carouselModel
                    delegate: launcher._carouselDelegate
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
                visible: launcher.selectedIndex > 0 && launcher.currentCount > 0
                onClicked: launcher.navigate(-1)
            }

            IconButton {
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                icon: Theme.iconArrowRight
                size: 24
                normalColor: Theme.fgDim
                visible: launcher.selectedIndex < launcher.currentCount - 1 && launcher.currentCount > 0
                onClicked: launcher.navigate(1)
            }
        }

    // Footer — fixed position below carousel
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: carouselArea.bottom
        anchors.topMargin: 16
        visible: true
        text: {
            // Disabled state
            if (launcher.activeCategory.disabledState) {
                const hint = launcher.activeCategory.disabledLegendHint || "";
                if (!launcher.editMode)
                    return (hint ? hint + "  |  " : "") + "\u2190 \u2192 Category  |  ESC close";
                return (hint ? hint + "  |  " : "") + "ESC back";
            }

            // Level 1: category browse
            if (!launcher.editMode)
                return "\u2190 \u2192 Category  |  Enter open  |  ESC close";

            // Level 2+: category overrides full legend
            if (launcher.activeCategory.legendOverride)
                return launcher.activeCategory.legendHint;

            // Level 2: standard item navigation
            if (launcher.currentCount === 0)
                return "ESC back";
            var t = (launcher.selectedIndex + 1) + " / " + launcher.currentCount
                  + "  |  \u2190 \u2192 Navigate";
            if (launcher.activeCategory.legendHint)
                t += "  |  " + launcher.activeCategory.legendHint;
            t += "  |  ESC back";
            return t;
        }
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.fgDim
    }
}
