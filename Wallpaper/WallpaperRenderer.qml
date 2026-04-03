import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config

// Background-layer wallpaper renderer.
// Creates one PanelWindow per screen at the Background layer, displaying
// the current wallpaper with a smooth crossfade transition on change.
Item {
    id: root

    property string currentWallpaper: UserSettings.wallpaperPath

    function setWallpaper(path) {
        currentWallpaper = path;
        UserSettings.setWallpaper(path);
    }

    // Load persisted wallpaper on startup
    Component.onCompleted: {
        if (UserSettings.wallpaperPath !== "") {
            currentWallpaper = UserSettings.wallpaperPath;
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: wallpaperWindow

            required property var modelData
            screen: modelData

            color: "transparent"
            visible: true

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "mcshell-wallpaper"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            // Track which image layer is "front" for crossfade
            property bool showingFirst: true
            property string pendingPath: ""

            // Two image layers for crossfade
            Image {
                id: imageA
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                opacity: wallpaperWindow.showingFirst ? 1.0 : 0.0
                source: ""

                Behavior on opacity {
                    NumberAnimation {
                        duration: 500
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            Image {
                id: imageB
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                opacity: wallpaperWindow.showingFirst ? 0.0 : 1.0
                source: ""

                Behavior on opacity {
                    NumberAnimation {
                        duration: 500
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            // React to wallpaper changes from root
            Connections {
                target: root
                function onCurrentWallpaperChanged() {
                    if (root.currentWallpaper === "") return;
                    const fileUrl = "file://" + root.currentWallpaper;
                    if (wallpaperWindow.showingFirst) {
                        // Load into B, then flip
                        imageB.source = fileUrl;
                        wallpaperWindow.showingFirst = false;
                    } else {
                        // Load into A, then flip
                        imageA.source = fileUrl;
                        wallpaperWindow.showingFirst = true;
                    }
                }
            }

            // Set initial wallpaper
            Component.onCompleted: {
                if (root.currentWallpaper !== "") {
                    imageA.source = "file://" + root.currentWallpaper;
                    wallpaperWindow.showingFirst = true;
                }
            }
        }
    }
}
