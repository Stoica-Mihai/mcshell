import QtQuick
import QtQuick.Layouts
import Quickshell
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
    legendHint: Theme.hintEnter + " apply"
    scanningState: !WallpaperScanner.loaded || WallpaperScanner.paths.length === 0
    scanningIcon: Theme.iconImage
    scanningHint: WallpaperScanner.loaded
        ? `No wallpapers found in ${UserSettings.wallpaperFolder}`
        : "Loading..."

    property string activeWallpaper: UserSettings.wallpaperPath

    // ── Lifecycle ──
    function onTabEnter() {
        if (!WallpaperScanner.loaded) WallpaperScanner.scan();
        else _syncItems();
    }

    function onTabLeave() {}

    function _syncItems() {
        const paths = WallpaperScanner.paths;
        let startIdx = 0;
        for (let i = 0; i < paths.length; i++) {
            if (paths[i] === activeWallpaper) { startIdx = i; break; }
        }
        setItems(paths, startIdx);
        launcher.selectedIndex = startIdx;
    }

    Connections {
        target: WallpaperScanner
        function onScanned() { root._syncItems(); }
    }

    // ── Search ──
    function onSearch(text) {
        setItems(filterByQuery(text, WallpaperScanner.paths,
            (item, q) => item.toLowerCase().indexOf(q) >= 0));
    }

    // ── Activate ──
    function onActivate(index) {
        if (!_validIndex(index)) return;
        ShellActions.setWallpaper(_sourceData[index]);
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
