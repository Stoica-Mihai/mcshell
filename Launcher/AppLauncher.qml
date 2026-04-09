import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Widgets

PanelWindow {
    id: launcher

    // ── Public API ──────────────────────────────────────
    property bool isOpen: false
    property bool _suppressCarouselAnim: false
    Timer {
        id: _animEnableTimer
        interval: Theme.animCarousel
        onTriggered: launcher._suppressCarouselAnim = false
    }


    function _initLauncher(tab, edit) {
        _suppressCarouselAnim = true;
        isOpen = true;
        visible = true;
        _openTransition();
        activeTab = tab;
        editMode = edit;
        searchField.text = "";
        selectedIndex = 0;
        _carouselDelegate = activeCategory.cardDelegate;
        _carouselModel = Qt.binding(() => activeCategory.model);
        activeCategory.onSearch("");
        activeCategory.onTabEnter();
        searchField.forceActiveFocus();
        Qt.callLater(tabHighlight._snapToTab, tab);
        _animEnableTimer.restart();
    }

    function open() { _initLauncher(0, false); }

    function close() {
        _closeTransition();
        editMode = false;
        searchField.text = "";
        for (let i = 0; i < categories.length; i++)
            categories[i].onTabLeave();
    }

    function toggle() {
        if (isOpen) close(); else open();
    }

    function openTab(name, cardId) {
        const idx = _tabIndex(name);
        if (idx < 0) return;
        if (!isOpen) {
            _initLauncher(idx, !!cardId);
        } else {
            switchTab(idx);
        }
        if (cardId) {
            editMode = true;
            activeCategory.onOpenCard(cardId);
        }
    }

    function refocusSearch() {
        searchField.forceActiveFocus();
    }

    // ── Open/close transitions ──────────────────────────
    property real _animProgress: 0

    function _openTransition() {
        _closeAnim.stop();
        _animProgress = 0;
        Qt.callLater(_openAnim.start);
    }

    function _closeTransition() {
        isOpen = false;
        _openAnim.stop();
        _closeAnim.start();
    }

    NumberAnimation {
        id: _openAnim
        target: launcher
        property: "_animProgress"
        from: 0; to: 1
        duration: Theme.animCarousel
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: _closeAnim
        target: launcher
        property: "_animProgress"
        from: launcher._animProgress; to: 0
        duration: Theme.animSmooth
        easing.type: Easing.InCubic
        onFinished: launcher.visible = false
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
        CategoryWifi { launcher: launcher },
        CategoryBluetooth { launcher: launcher },
        CategoryWallpaper { launcher: launcher },
        CategorySettings { launcher: launcher }
    ]

    // ── Tab state ───────────────────────────────────────
    property int activeTab: 0
    onActiveTabChanged: tabHighlight.animateTo(activeTab)
    readonly property int tabCount: categories.length
    readonly property var activeCategory: categories[activeTab]
    readonly property var currentList: activeCategory.model
    readonly property int currentCount: carouselRepeater.count
    readonly property bool hasItems: currentCount > 0
    onHasItemsChanged: if (!hasItems && editMode) editMode = false

    // Carousel model/delegate — reset together on tab switch to prevent
    // cross-contamination (new delegate rendering against old model data)
    property var _carouselModel: activeCategory.model
    property Component _carouselDelegate: activeCategory.cardDelegate
    readonly property string searchText: searchField.text

    property int selectedIndex: 0
    property bool editMode: false

    // ── Carousel config ─────────────────────────────────
    readonly property int sideCount: 5
    readonly property real stripWidth: 100
    readonly property real expandedWidth: 700
    readonly property real carouselHeight: 480
    readonly property real stripSpacing: 6

    function navigate(delta) {
        if (!hasItems) return;
        selectedIndex = Math.max(0, Math.min(currentCount - 1, selectedIndex + delta));
        activeCategory.growItems(selectedIndex);
    }

    function calcRowX() {
        if (!hasItems) return carouselArea.width / 2;
        const visibleLeftCount = Math.min(selectedIndex, sideCount);
        const leftWidth = visibleLeftCount * (stripWidth + stripSpacing);
        const centerOffset = expandedWidth / 2;
        return carouselArea.width / 2 - leftWidth - centerOffset;
    }

    // ── Tab switching ───────────────────────────────────
    function _tabIndex(name) {
        for (let i = 0; i < categories.length; i++)
            if (categories[i].tabName === name) return i;
        console.warn("AppLauncher: unknown tab name:", name);
        return -1;
    }

    function switchTab(tab) {
        if (tab < 0 || tab >= categories.length) return;
        if (leftAnim.running || rightAnim.running) return;
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
        _suppressCarouselAnim = true;
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
        _animEnableTimer.restart();
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
        opacity: launcher._animProgress
        MouseArea { anchors.fill: parent; onClicked: launcher.close() }
    }

    // Content wrapper — animated on open/close
    Item {
        id: _contentRoot
        anchors.fill: parent
        opacity: launcher._animProgress
        scale: 0.85 + 0.15 * launcher._animProgress
        transformOrigin: Item.Center

    // Search bar — fixed position above center
    Item {
        id: searchBar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: carouselArea.top
        anchors.bottomMargin: 20
        width: Math.min(740, parent.width - 80)
        height: 44

            Canvas {
                id: searchBarBg
                anchors.fill: parent
                Connections {
                    target: Theme
                    function onSurfaceContainerChanged() { searchBarBg.requestPaint(); }
                    function onOutlineVariantChanged() { searchBarBg.requestPaint(); }
                }
                onPaint: {
                    var ctx = getContext("2d"), s = Theme.barDiagSlant;
                    ctx.clearRect(0, 0, width, height);
                    ctx.beginPath();
                    ctx.moveTo(s, 0);
                    ctx.lineTo(width, 0);
                    ctx.lineTo(width - s, height);
                    ctx.lineTo(0, height);
                    ctx.closePath();
                    ctx.fillStyle = Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.92);
                    ctx.fill();
                    ctx.strokeStyle = Theme.outlineVariant;
                    ctx.lineWidth = 1;
                    ctx.stroke();
                }
            }

            // ── Tab underline highlight ────────────────────
            Item {
                id: tabHighlight
                anchors.fill: parent
                visible: false

                readonly property real _pad: 4
                property real _lineLeft: 0
                property real _lineRight: 0

                NumberAnimation {
                    id: leftAnim
                    target: tabHighlight; property: "_lineLeft"
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    id: rightAnim
                    target: tabHighlight; property: "_lineRight"
                    easing.type: Easing.InOutQuad
                }

                // ── Snap (no animation) ──
                property var _pendingConn: null
                function _snapToTab(idx) {
                    if (_pendingConn) { _pendingConn.enabled = false; _pendingConn = null; }
                    const item = tabRepeater.itemAt(idx);
                    if (!item) return;
                    if (item.width > 0) {
                        _applySnap(item);
                    } else {
                        _pendingConn = item.widthChanged.connect(function() {
                            if (item.width > 0) {
                                item.widthChanged.disconnect(arguments.callee);
                                tabHighlight._applySnap(item);
                            }
                        });
                    }
                }

                function _applySnap(item) {
                    const pos = item.mapToItem(searchBar, 0, 0);
                    leftAnim.stop(); rightAnim.stop();
                    _lineLeft = pos.x - _pad;
                    _lineRight = pos.x + item.width + _pad;
                    visible = true;
                }

                // ── Animated transition ──
                function animateTo(idx) {
                    const item = tabRepeater.itemAt(idx);
                    if (!item) return;
                    if (!visible) { _snapToTab(idx); return; }
                    const pos = item.mapToItem(searchBar, 0, 0);
                    const targetLeft = pos.x - _pad;
                    const targetRight = pos.x + item.width + _pad;
                    const movingRight = targetLeft > _lineLeft;

                    leftAnim.stop(); rightAnim.stop();
                    leftAnim.to = targetLeft;
                    rightAnim.to = targetRight;
                    // Leading edge is fast, trailing is slower
                    leftAnim.duration = movingRight ? 250 : 120;
                    rightAnim.duration = movingRight ? 120 : 250;
                    leftAnim.start();
                    rightAnim.start();
                }

                // ── The underline ──
                Rectangle {
                    x: tabHighlight._lineLeft
                    y: searchBar.height - 3
                    width: tabHighlight._lineRight - tabHighlight._lineLeft
                    height: 2
                    radius: 1
                    color: launcher.editMode ? Theme.fgDim : Theme.accent
                    Behavior on color { ColorAnimation { duration: Theme.animNormal } }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: Theme.spacingMedium

                // Tab buttons — driven by categories
                Repeater {
                    id: tabRepeater
                    model: launcher.categories

                    delegate: Item {
                        required property var modelData
                        required property int index
                        Layout.preferredWidth: tabContent.implicitWidth + 16
                        Layout.preferredHeight: 28

                        RowLayout {
                            id: tabContent
                            anchors.centerIn: parent
                            spacing: Theme.spacingTiny

                            Text {
                                text: modelData.tabIcon
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.fontSizeSmall
                                color: launcher.activeTab === index ? Theme.fg : Theme.fgDim
                                Behavior on color { ColorAnimation { duration: Theme.animNormal } }
                            }

                            Text {
                                text: modelData.tabLabel
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                color: launcher.activeTab === index ? Theme.fg : Theme.fgDim
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
                Rectangle { width: 1; Layout.preferredHeight: 20; color: Theme.outlineVariant }

                // Search icon
                Text {
                    text: Theme.iconSearch
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSizeMedium
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
                                if (launcher.hasItems) {
                                    launcher.editMode = true;
                                    event.accepted = true;
                                }
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

                    Keys.onReleased: event => {
                        if (launcher.activeCategory.onKeyReleased?.(event))
                            event.accepted = true;
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
                visible: !launcher.hasItems
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
                      && !launcher.hasItems
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
                      && !launcher.hasItems
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
                visible: launcher.hasItems

                Behavior on x {
                    enabled: launcher.isOpen && !launcher._suppressCarouselAnim
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
                visible: launcher.selectedIndex > 0 && launcher.hasItems
                onClicked: launcher.navigate(-1)
            }

            IconButton {
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                icon: Theme.iconArrowRight
                size: 24
                normalColor: Theme.fgDim
                visible: launcher.selectedIndex < launcher.currentCount - 1 && launcher.hasItems
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
                    return Theme.legend(...[hint, Theme.hintCategory, Theme.hintClose].filter(Boolean));
                return Theme.legend(...[hint, Theme.hintBack].filter(Boolean));
            }

            // Level 1: category browse
            if (!launcher.editMode)
                return Theme.legend(Theme.hintCategory, Theme.hintEnter + " open", Theme.hintClose);

            // Level 2+: category overrides full legend
            if (launcher.activeCategory.legendOverride)
                return launcher.activeCategory.legendHint;

            // Level 2: standard item navigation
            if (!launcher.hasItems)
                return Theme.hintBack;
            var parts = [(launcher.selectedIndex + 1) + " / " + launcher.currentCount, Theme.hintNav];
            if (launcher.activeCategory.legendHint)
                parts.push(launcher.activeCategory.legendHint);
            parts.push(Theme.hintBack);
            return Theme.legend(...parts);
        }
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.fgDim
    }

    } // _contentRoot
}
