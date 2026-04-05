import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Config
import qs.Core
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
    legendHint: Theme.hintEnter + " apply"
    scanningState: !loaded || _fullPaths.length === 0
    scanningIcon: Theme.iconImage
    scanningHint: loaded ? "No wallpapers found in " + UserSettings.wallpaperFolder : "Loading..."

    // ── Data ──
    property bool loaded: false
    property var _fullPaths: []
    property var _scanLines: []
    property string activeWallpaper: UserSettings.wallpaperPath
    property int activeIndex: 0
    property string _lastFolder: ""

    // ── Lifecycle ──
    function onTabEnter() {
        const folder = UserSettings.wallpaperFolder;
        if (!loaded || folder !== _lastFolder) {
            _lastFolder = folder;
            scanFolder();
        } else {
            setItems(_fullPaths, activeIndex);
            launcher.selectedIndex = activeIndex;
        }
    }

    function onTabLeave() {}

    // ── Folder scanning ──
    function scanFolder() {
        const folder = UserSettings.wallpaperFolder;
        if (folder === "") return;
        loaded = false;
        _fullPaths = [];
        _scanLines = [];
        scanProc.command = [
            "find", folder, "-maxdepth", "1", "-type", "f",
            "(", "-name", "*.png", "-o", "-name", "*.jpg",
            "-o", "-name", "*.jpeg",
            "-o", "-name", "*.bmp", ")"
        ];
        scanProc.running = true;
    }

    SafeProcess {
        id: scanProc
        failMessage: "wallpaper scan failed — check folder path"
        onRead: data => { root._scanLines.push(data.trim()); }
        onFinished: {
            const sorted = root._scanLines.slice().sort();
            root._fullPaths = sorted;
            root._scanLines = [];
            root.loaded = true;
            // Jump to the active wallpaper
            let startIdx = 0;
            for (let i = 0; i < sorted.length; i++) {
                if (sorted[i] === root.activeWallpaper) {
                    root.activeIndex = i;
                    startIdx = i;
                    break;
                }
            }
            root.setItems(sorted, startIdx);
            root.launcher.selectedIndex = startIdx;
        }
        onFailed: {
            root.loaded = true;
        }
    }

    // ── Search ──
    function onSearch(text) {
        if (text === "") { setItems(_fullPaths, activeIndex); return; }
        setItems(filterByQuery(text, _fullPaths,
            (item, q) => item.toLowerCase().indexOf(q) >= 0));
    }

    // ── Activate ──
    function onActivate(index) {
        if (!_validIndex(index)) return;
        const path = _sourceData[index];
        activeIndex = _fullPaths.indexOf(path);
        ShellActions.setWallpaper(path);
    }

    // ── Card delegate ──
    cardDelegate: Component {
        CarouselStrip {
            id: wallStrip
            launcher: root.launcher
            showBorder: isCurrent || isActive

            readonly property string wallPath: typeof modelData === "string" ? modelData : ""
            readonly property bool isActive: wallPath === root.activeWallpaper
            readonly property string fileName: {
                const parts = wallPath.split("/");
                return parts[parts.length - 1];
            }

            // Collapsed: thumbnail (small sourceSize for fast loading)
            OptImage {
                anchors.fill: parent
                visible: !wallStrip.isCurrent
                source: wallStrip.isVisible && wallStrip.wallPath ? "file://" + wallStrip.wallPath : ""
                sourceSize.height: root.launcher.carouselHeight
            }

            // Expanded: full preview with filename
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

                // Active checkmark
                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: Theme.spacingNormal
                    width: 28
                    height: 28
                    radius: Theme.radiusLarge
                    color: Theme.accent
                    visible: wallStrip.isActive

                    Text {
                        anchors.centerIn: parent
                        text: Theme.iconCheck
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSizeBody
                        color: Theme.bgSolid
                    }
                }
            }
        }
    }
}
