pragma Singleton

import QtQuick
import Quickshell
import qs.Config
import qs.Core

// Lists image files in UserSettings.wallpaperFolder. Shared between the
// launcher's Wall picker and the auto-rotator so the `find` command and
// line collector aren't duplicated.
Singleton {
    id: root

    property var paths: []
    property bool loaded: false
    property bool scanning: false
    property string _lastFolder: ""
    property var _lines: []

    signal scanned()

    function scan() {
        const folder = UserSettings.wallpaperFolder;
        if (folder === "" || scanning) return;
        scanning = true;
        loaded = false;
        _lastFolder = folder;
        _lines = [];
        scanProc.command = [
            "find", folder, "-maxdepth", "1", "-type", "f",
            "(", "-name", "*.png", "-o", "-name", "*.jpg",
            "-o", "-name", "*.jpeg",
            "-o", "-name", "*.bmp", ")"
        ];
        scanProc.running = true;
    }

    Connections {
        target: UserSettings
        function onWallpaperFolderChanged() { root.scan(); }
    }

    SafeProcess {
        id: scanProc
        failMessage: "wallpaper scan failed — check folder path"
        onRead: data => root._lines.push(data.trim())
        onFinished: {
            root.paths = root._lines.slice().sort();
            root._lines = [];
            root.loaded = true;
            root.scanning = false;
            root.scanned();
        }
        onFailed: {
            root._lines = [];
            root.loaded = true;
            root.scanning = false;
        }
    }
}
