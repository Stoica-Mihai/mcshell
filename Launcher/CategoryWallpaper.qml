import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Config
import qs.Core
import qs.Wallpaper

LauncherCategory {
    id: root

    // ── Launcher reference ──
    required property var launcher

    signal wallpaperSelected(string path)

    // ── Tab config ──
    tabLabel: "Wall"
    tabIcon: Theme.iconImage
    searchPlaceholder: "Search wallpapers..."
    legendHint: "Enter apply"
    scanningState: !loaded || allPaths.length === 0
    scanningIcon: Theme.iconImage
    scanningHint: loaded ? "No wallpapers found in " + WallpaperConfig.folder : "Loading..."

    // ── Data ──
    model: launcher.searchText !== "" ? filteredPaths : lazyWall.count

    property bool loaded: false
    property var allPaths: []
    property var filteredPaths: []
    property var _scanLines: []
    property string activeWallpaper: WallpaperConfig.wallpaper
    property int activeIndex: 0

    LazyModel {
        id: lazyWall
        sourceModel: root.allPaths
        currentIndex: root.launcher.selectedIndex
    }

    // ── Lifecycle ──
    function onTabEnter() {
        if (!loaded) scanFolder();
        else {
            launcher.selectedIndex = activeIndex;
            lazyWall.reset();
        }
    }

    function onTabLeave() {
        lazyWall.reset();
    }

    // ── Folder scanning ──
    function scanFolder() {
        const folder = WallpaperConfig.folder;
        if (folder === "") return;
        loaded = false;
        allPaths = [];
        _scanLines = [];
        scanProc.command = [
            "find", folder, "-maxdepth", "1", "-type", "f",
            "(", "-name", "*.png", "-o", "-name", "*.jpg",
            "-o", "-name", "*.jpeg", "-o", "-name", "*.webp",
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
            root.allPaths = sorted;
            root._scanLines = [];
            root.loaded = true;
            // Jump to the active wallpaper
            for (let i = 0; i < sorted.length; i++) {
                if (sorted[i] === root.activeWallpaper) {
                    root.activeIndex = i;
                    root.launcher.selectedIndex = i;
                    break;
                }
            }
        }
        onFailed: {
            root.loaded = true;
        }
    }

    // ── Search ──
    function onSearch(text) {
        const query = (text || "").toLowerCase().trim();
        if (query === "") { filteredPaths = []; return; }
        const results = [];
        for (let i = 0; i < allPaths.length; i++) {
            if (allPaths[i].toLowerCase().indexOf(query) >= 0)
                results.push(allPaths[i]);
        }
        filteredPaths = results;
    }

    // ── Activate ──
    function onActivate(index) {
        const path = launcher.searchText !== ""
            ? filteredPaths[index]
            : allPaths[index];
        if (!path) return;
        activeWallpaper = path;
        activeIndex = allPaths.indexOf(path);
        WallpaperConfig.wallpaper = path;
        wallpaperSelected(path);
    }

    // ── Card delegate ──
    cardDelegate: Component {
        CarouselStrip {
            id: wallStrip
            selectedIndex: root.launcher.selectedIndex
            sideCount: root.launcher.sideCount
            expandedWidth: root.launcher.expandedWidth
            stripWidth: root.launcher.stripWidth
            carouselHeight: root.launcher.carouselHeight
            focused: root.launcher.editMode
            showBorder: isCurrent || isActive
            onActivated: root.onActivate(index)
            onSelected: root.launcher.selectedIndex = index

            readonly property string wallPath: {
                const src = typeof modelData === "string" ? modelData : root.allPaths[index];
                return src !== undefined ? src : "";
            }
            readonly property bool isActive: wallPath === root.activeWallpaper
            readonly property string fileName: {
                const parts = wallPath.split("/");
                return parts[parts.length - 1];
            }

            // Collapsed: thumbnail (small sourceSize for fast loading)
            Image {
                anchors.fill: parent
                visible: !wallStrip.isCurrent
                source: wallStrip.isVisible && wallStrip.wallPath ? "file://" + wallStrip.wallPath : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.height: root.launcher.carouselHeight
            }

            // Expanded: full preview with filename
            Item {
                anchors.fill: parent
                visible: wallStrip.isCurrent

                Image {
                    anchors.fill: parent
                    source: wallStrip.wallPath ? "file://" + wallStrip.wallPath : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
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
                        anchors.margins: 10
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
                    anchors.margins: 8
                    width: 28
                    height: 28
                    radius: 14
                    color: Theme.accent
                    visible: wallStrip.isActive

                    Text {
                        anchors.centerIn: parent
                        text: Theme.iconCheck
                        font.family: Theme.iconFont
                        font.pixelSize: 14
                        color: Theme.bgSolid
                    }
                }
            }
        }
    }
}
