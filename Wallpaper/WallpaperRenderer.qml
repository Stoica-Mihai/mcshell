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

            // Per-screen wallpaper path. Qt's property tracker captures the
            // perScreenMap/folder/path reads inside the helper, so the binding
            // stays reactive.
            readonly property string _screenWallpaper: UserSettings.wallpaperForScreen(modelData.name)

            // Track which image layer is "front" for crossfade
            property bool showingFirst: true
            property string _lastApplied: ""

            // Decode to the screen's pixel size — a 4K JPEG on a 1080p output
            // otherwise allocates ~32 MB per layer (×2 for crossfade) before
            // the GPU even sees it. modelData is the QScreen for this window.
            readonly property int _decodeW: modelData.width
            readonly property int _decodeH: modelData.height

            // Two image layers for crossfade
            Image {
                id: imageA
                anchors.fill: parent
                fillMode: root._fillMode
                asynchronous: true
                cache: true
                smooth: true
                sourceSize.width: wallpaperWindow._decodeW
                sourceSize.height: wallpaperWindow._decodeH
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
                sourceSize.width: wallpaperWindow._decodeW
                sourceSize.height: wallpaperWindow._decodeH
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
