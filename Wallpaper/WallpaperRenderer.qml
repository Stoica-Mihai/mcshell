import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Core

// Background-layer wallpaper renderer.
// Creates one PanelWindow per screen at the Background layer, displaying
// the current wallpaper with a smooth crossfade transition on change.
Item {
    id: root

    readonly property int _fillMode: {
        switch (UserSettings.wallpaperFillMode) {
            case "fit": return Image.PreserveAspectFit;
            case "stretch": return Image.Stretch;
            case "tile": return Image.Tile;
            default: return Image.PreserveAspectCrop;
        }
    }

    function setWallpaper(path) {
        UserSettings.setWallpaper(path);
    }

    Variants {
        model: Quickshell.screens

        delegate: OverlayWindow {
            id: wallpaperWindow
            namespace: Namespaces.wallpaper
            layer: WlrLayer.Background
            focusMode: WlrKeyboardFocus.None

            required property var modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // Per-screen wallpaper — inline binding with explicit deps for
            // reliable QML property tracking (avoids opaque function call).
            readonly property string _screenWallpaper: {
                const filename = UserSettings.perScreenMap[modelData.name];
                if (filename)
                    return UserSettings.wallpaperFolder + "/" + filename;
                return UserSettings.wallpaperPath;
            }

            // Track which image layer is "front" for crossfade
            property bool showingFirst: true
            property string _lastApplied: ""

            // Two image layers for crossfade
            Image {
                id: imageA
                anchors.fill: parent
                fillMode: root._fillMode
                asynchronous: true
                cache: true
                smooth: true
                opacity: wallpaperWindow.showingFirst ? 1.0 : 0.0
                source: ""

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animCrossfade
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            Image {
                id: imageB
                anchors.fill: parent
                fillMode: root._fillMode
                asynchronous: true
                cache: true
                smooth: true
                opacity: wallpaperWindow.showingFirst ? 0.0 : 1.0
                source: ""

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animCrossfade
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            function _applyWallpaper() {
                const wp = wallpaperWindow._screenWallpaper;
                if (wp === "" || wp === wallpaperWindow._lastApplied) return;
                wallpaperWindow._lastApplied = wp;
                const fileUrl = "file://" + wp;
                if (wallpaperWindow.showingFirst) {
                    imageB.source = fileUrl;
                    wallpaperWindow.showingFirst = false;
                } else {
                    imageA.source = fileUrl;
                    wallpaperWindow.showingFirst = true;
                }
            }

            on_ScreenWallpaperChanged: _applyWallpaper()

            // Set initial wallpaper
            Component.onCompleted: {
                const wp = wallpaperWindow._screenWallpaper;
                if (wp !== "") {
                    imageA.source = "file://" + wp;
                    wallpaperWindow.showingFirst = true;
                    wallpaperWindow._lastApplied = wp;
                }
            }
        }
    }
}
