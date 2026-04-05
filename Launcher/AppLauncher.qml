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
    function _initLauncher(tab, edit) {
        isOpen = true;
        visible = true;
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
    }

    function open() { _initLauncher(0, false); }

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
    readonly property real stripWidth: 80
    readonly property real expandedWidth: 500
    readonly property real carouselHeight: 350
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
        if (blobAnim.running) return;
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

            // ── Liquid blob tab highlight ──────────────────
            Canvas {
                id: tabHighlight
                anchors.fill: parent
                visible: false

                property color blobColor: launcher.editMode ? Theme.bgHover : Theme.accent
                onBlobColorChanged: requestPaint()

                // Blob geometry
                readonly property real blobH: 28
                readonly property real blobY: (searchBar.height - blobH) / 2
                readonly property real blobPad: 8

                // Resting position (where the blob sits when not animating)
                property real _restX: 0
                property real _restW: 0

                // Animation state: -1 = at rest, 0..1 = transitioning
                property real _progress: -1
                property real _sourceX: 0
                property real _sourceW: 0
                property real _targetX: 0
                property real _targetW: 0

                on_ProgressChanged: requestPaint()

                NumberAnimation {
                    id: blobAnim
                    target: tabHighlight; property: "_progress"
                    from: 0; to: 1
                    duration: Theme.animSmooth
                    easing.type: Easing.InOutQuad
                    onFinished: {
                        tabHighlight._restX = tabHighlight._targetX;
                        tabHighlight._restW = tabHighlight._targetW;
                        tabHighlight._progress = -1;
                        tabHighlight.requestPaint();
                    }
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
                    _restX = pos.x - blobPad;
                    _restW = item.width + blobPad * 2;
                    _progress = -1;
                    visible = true;
                    requestPaint();
                }

                // ── Animated transition ──
                function animateTo(idx) {
                    const item = tabRepeater.itemAt(idx);
                    if (!item) return;
                    if (!visible) { _snapToTab(idx); return; }
                    const pos = item.mapToItem(searchBar, 0, 0);
                    blobAnim.stop();
                    _sourceX = _restX;
                    _sourceW = _restW;
                    _targetX = pos.x - blobPad;
                    _targetW = item.width + blobPad * 2;
                    blobAnim.start();
                }

                // ── Drawing ──
                function _lerp(a, b, t) { return a + (b - a) * t; }
                function _smoothstep(t) { return t * t * (3 - 2 * t); }

                // Skew offset proportional to blob height
                readonly property real _skew: Theme.barDiagSlant * blobH / searchBar.height

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.fillStyle = blobColor;

                    var h = blobH, top = blobY, s = _skew;

                    if (_progress < 0) {
                        // At rest — parallelogram
                        _drawSkewed(ctx, _restX, top, _restW, h, s);
                        return;
                    }

                    // Animated: leading edge races ahead, trailing follows
                    var p = _progress;
                    var movingRight = _targetX >= _sourceX;

                    var leadT = _smoothstep(Math.min(1, p * 1.4));
                    var trailT = _smoothstep(Math.max(0, (p - 0.2) / 0.8));

                    var left, right;
                    if (movingRight) {
                        left  = _lerp(_sourceX, _targetX, trailT);
                        right = _lerp(_sourceX + _sourceW, _targetX + _targetW, leadT);
                    } else {
                        left  = _lerp(_sourceX, _targetX, leadT);
                        right = _lerp(_sourceX + _sourceW, _targetX + _targetW, trailT);
                    }

                    // Pinch in the middle for liquid stretch effect
                    var blobW = right - left;
                    var naturalW = Math.max(_sourceW, _targetW);
                    var stretch = blobW / naturalW;
                    var pinch = Math.min(0.95, Math.max(0, 1 - 1 / stretch) * 20);
                    var pinchH = h * (1 - pinch);
                    var midX = (left + right) / 2;
                    var pinchTop = top + (h - pinchH) / 2;
                    var pinchBot = top + (h + pinchH) / 2;

                    // Draw skewed blob with bezier pinch
                    ctx.beginPath();
                    ctx.moveTo(left + s, top);
                    ctx.quadraticCurveTo(midX + s * 0.5, pinchTop, right, top);
                    ctx.lineTo(right - s, top + h);
                    ctx.quadraticCurveTo(midX - s * 0.5, pinchBot, left, top + h);
                    ctx.closePath();
                    ctx.fill();
                }

                function _drawSkewed(ctx, px, py, pw, ph, s) {
                    ctx.beginPath();
                    ctx.moveTo(px + s, py);
                    ctx.lineTo(px + pw, py);
                    ctx.lineTo(px + pw - s, py + ph);
                    ctx.lineTo(px, py + ph);
                    ctx.closePath();
                    ctx.fill();
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
                                color: launcher.activeTab === index
                                    ? (launcher.editMode ? Theme.accent : Theme.bgSolid)
                                    : Theme.fgDim
                                Behavior on color { ColorAnimation { duration: Theme.animNormal } }
                            }

                            Text {
                                text: modelData.tabLabel
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
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
}
