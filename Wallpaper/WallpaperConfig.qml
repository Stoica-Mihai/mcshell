pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Persistent wallpaper configuration.
// Reads/writes ~/.config/mcshell/wallpaper.json via FileView + JsonAdapter.
// Stores the selected folder path and current wallpaper path.
Singleton {
    id: root

    property string folder: ""
    property string wallpaper: ""

    readonly property bool loaded: configFile.loaded

    // Resolve default folder on startup
    Component.onCompleted: {
        defaultFolderProc.running = true;
    }

    // Check if ~/Pictures/Wallpapers/ exists, fallback to ~/Pictures/
    Process {
        id: defaultFolderProc
        command: ["bash", "-c", "if [ -d \"$HOME/Pictures/Wallpapers\" ]; then echo \"$HOME/Pictures/Wallpapers\"; else echo \"$HOME/Pictures\"; fi"]
        stdout: SplitParser {
            onRead: data => {
                root._defaultFolder = data.trim();
                if (root.folder === "") {
                    root.folder = root._defaultFolder;
                }
            }
        }
    }

    property string _defaultFolder: ""

    FileView {
        id: configFile
        path: Quickshell.env("HOME") + "/.config/mcshell/wallpaper.json"
        blockLoading: true
        printErrors: false

        onLoaded: {
            try {
                const data = JSON.parse(configFile.text());
                if (data.folder && data.folder !== "") root.folder = data.folder;
                if (data.wallpaper && data.wallpaper !== "") root.wallpaper = data.wallpaper;
            } catch (e) {
                // File doesn't exist or is malformed — use defaults
            }
        }
    }

    function save() {
        const data = JSON.stringify({
            folder: root.folder,
            wallpaper: root.wallpaper
        }, null, 2);
        ensureDirProc.running = true;
        root._pendingSave = data;
    }

    property string _pendingSave: ""

    // Ensure config directory exists before writing
    Process {
        id: ensureDirProc
        command: ["mkdir", "-p", Quickshell.env("HOME") + "/.config/mcshell"]
        onExited: {
            if (root._pendingSave !== "") {
                configFile.setText(root._pendingSave);
                root._pendingSave = "";
            }
        }
    }

    onWallpaperChanged: {
        if (wallpaper !== "") save();
    }

    onFolderChanged: {
        if (folder !== "") save();
    }
}
