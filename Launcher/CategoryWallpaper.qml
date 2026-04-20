import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Config
import qs.Core
import qs.Wallpaper
import qs.Widgets

LauncherCategory {
    id: root

    // ── Launcher reference ──
    required property var launcher

    // ── Tab config ──
    tabName: "wallpaper"
    tabLabel: "Wall"
    tabIcon: Theme.iconImage
    searchPlaceholder: "Search wallpapers..."
    legendHint: Theme.legend(
        Theme.hintEnter + " apply to " + _screenNames[_selectedScreen],
        "Tab screen"
    )
    scanningState: !WallpaperScanner.loaded || WallpaperScanner.paths.length === 0
    scanningIcon: Theme.iconImage
    scanningHint: WallpaperScanner.loaded
        ? `No wallpapers found in ${UserSettings.wallpaperFolder}`
        : "Loading..."

    // ── Screen state ──
    readonly property var _screenList: Quickshell.screens
    readonly property var _screenNames: UserSettings.screenNames
    property int _selectedScreen: 0  // 0 = All, 1+ = specific screen

    // Wallpaper path for a given screen name
    function _wallpaperFor(screenName) {
        const map = UserSettings.perScreenMap;
        const folder = UserSettings.wallpaperFolder;
        if (map[screenName]) return folder + "/" + map[screenName];
        return UserSettings.wallpaperPath;
    }

    // Precomputed reverse map: wallpaper path → [screen names].
    // Evaluated once when perScreenMap/wallpaperPath changes, not per-card.
    readonly property var _screensByPath: {
        const map = UserSettings.perScreenMap;
        const folder = UserSettings.wallpaperFolder;
        const global = UserSettings.wallpaperPath;
        const result = {};
        for (let i = 0; i < _screenList.length; i++) {
            const name = _screenList[i].name;
            const wp = map[name] ? folder + "/" + map[name] : global;
            if (!result[wp]) result[wp] = [];
            result[wp].push(name);
        }
        return result;
    }

    // ── Focused screen detection ──
    Process {
        id: _focusDetect
        command: ["niri", "msg", "-j", "focused-output"]
        stdout: StdioCollector {
            onStreamFinished: {
                let focused = "";
                try { focused = JSON.parse(this.text).name; } catch(e) {}
                for (let i = 0; i < root._screenNames.length; i++) {
                    if (root._screenNames[i] === focused) {
                        root._selectedScreen = i;
                        break;
                    }
                }
                root._syncItems();
            }
        }
    }

    // ── Lifecycle ──
    function onTabEnter() {
        if (!WallpaperScanner.loaded) WallpaperScanner.scan();
        else _focusDetect.running = true;
    }

    function onTabLeave() {}

    function _syncItems() {
        const paths = WallpaperScanner.paths;
        // Land on the selected screen's wallpaper
        let target = UserSettings.wallpaperPath;
        if (_selectedScreen > 0)
            target = _wallpaperFor(_screenNames[_selectedScreen]);

        let startIdx = 0;
        for (let i = 0; i < paths.length; i++) {
            if (paths[i] === target) { startIdx = i; break; }
        }
        setItems(paths, startIdx);
        launcher.selectedIndex = startIdx;
    }

    Connections {
        target: WallpaperScanner
        function onScanned() {
            if (launcher.isOpen) _focusDetect.running = true;
        }
    }

    // ── Search ──
    function onSearch(text) {
        setItems(filterByQuery(text, WallpaperScanner.paths,
            (item, q) => item.toLowerCase().indexOf(q) >= 0));
    }

    // ── Activate ──
    function onActivate(index) {
        if (!_validIndex(index)) return;
        const path = _sourceData[index];
        if (_selectedScreen === 0)
            ShellActions.setWallpaper(path);
        else
            UserSettings.setWallpaperForScreen(_screenNames[_selectedScreen], path);
    }

    // ── Tab key cycles monitors ──
    function onKeyPressed(event) {
        if (event.key === Qt.Key_Tab) {
            _selectedScreen = (_selectedScreen + 1) % _screenNames.length;
            return true;
        }
        if (event.key === Qt.Key_Backtab) {
            _selectedScreen = (_selectedScreen - 1 + _screenNames.length) % _screenNames.length;
            return true;
        }
        return false;
    }

    // ── Monitor strip header ──
    headerDelegate: Component {
        Row {
            spacing: Theme.spacingLarge

            Repeater {
                model: root._screenList

                Rectangle {
                    id: monitorSlot
                    required property var modelData
                    required property int index

                    readonly property bool isSelected: root._selectedScreen === 0 || (index + 1) === root._selectedScreen
                    readonly property string screenWp: root._wallpaperFor(modelData.name)

                    width: 180
                    height: 100
                    color: "transparent"
                    border.width: isSelected ? 2 : 1
                    border.color: isSelected ? Theme.accent : Theme.border

                    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                    Image {
                        anchors.fill: parent
                        anchors.margins: parent.border.width
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: false
                        cache: true
                        source: monitorSlot.screenWp ? "file://" + monitorSlot.screenWp : ""
                        sourceSize.width: 180
                        sourceSize.height: 100
                    }

                    // Gradient + label at bottom
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 28
                        color: "transparent"

                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.8) }
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.margins: Theme.spacingSmall
                            text: modelData.name
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeMini
                            font.bold: true
                            color: monitorSlot.isSelected ? Theme.accent : Theme.fg
                        }
                    }

                    // Selected indicator dot
                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: Theme.spacingSmall
                        width: 8; height: 8
                        radius: 4
                        color: Theme.accent
                        visible: monitorSlot.isSelected
                    }
                }
            }
        }
    }

    // ── Card delegate ──
    cardDelegate: Component {
        CarouselStrip {
            id: wallStrip
            launcher: root.launcher
            showBorder: isCurrent || _assignedScreens.length > 0

            readonly property string wallPath: typeof modelData === "string" ? modelData : ""
            // Stable array reference: only reassign when the content actually
            // changes, otherwise rapid wallpaper swaps rebuild a fresh array
            // every UserSettings.wallpaper* tick and the badge Repeater's
            // regenerate races with teardown → QmlModels SIGSEGV.
            property var _assignedScreens: []
            readonly property var _nextAssignedScreens: root._screensByPath[wallPath] || []
            on_NextAssignedScreensChanged: {
                const cur = _assignedScreens;
                const next = _nextAssignedScreens;
                if (cur.length !== next.length) { _assignedScreens = next; return; }
                for (let i = 0; i < next.length; i++) {
                    if (cur[i] !== next[i]) { _assignedScreens = next; return; }
                }
            }
            Component.onCompleted: _assignedScreens = _nextAssignedScreens
            readonly property string fileName: {
                const parts = wallPath.split("/");
                return parts[parts.length - 1];
            }

            // Collapsed: thumbnail
            OptImage {
                anchors.fill: parent
                visible: !wallStrip.isCurrent
                source: wallStrip.isVisible && wallStrip.wallPath ? "file://" + wallStrip.wallPath : ""
                sourceSize.height: root.launcher.carouselHeight
            }

            // Expanded: full preview with filename + screen badges
            Item {
                anchors.fill: parent
                visible: wallStrip.isCurrent

                OptImage {
                    anchors.fill: parent
                    source: wallStrip.wallPath ? "file://" + wallStrip.wallPath : ""
                    smooth: true
                    sourceSize.height: root.launcher.carouselHeight
                }

                // Filename gradient
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 60

                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.7) }
                    }

                    Text {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: Theme.spacingMedium
                        text: wallStrip.fileName
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.fg
                        elide: Text.ElideRight
                    }
                }

                // Screen badges (top-right)
                Flow {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: Theme.spacingNormal
                    spacing: Theme.spacingTiny
                    layoutDirection: Qt.RightToLeft
                    visible: wallStrip._assignedScreens.length > 0

                    Repeater {
                        model: wallStrip._assignedScreens

                        Rectangle {
                            required property string modelData
                            height: 20
                            width: badgeText.implicitWidth + Theme.spacingMedium * 2
                            radius: Theme.radiusMedium
                            color: Theme.accent

                            Text {
                                id: badgeText
                                anchors.centerIn: parent
                                text: modelData
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeMini
                                font.bold: true
                                color: Theme.bgSolid
                            }
                        }
                    }
                }
            }
        }
    }
}
