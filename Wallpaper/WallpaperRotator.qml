import QtQuick
import qs.Config
import qs.Core

// Auto-rotates the wallpaper on a fixed interval, picking a random image
// from WallpaperScanner.paths that isn't the one currently shown.
Item {
    id: root

    // Injected from shell.qml so the rotator can idle while the session
    // is locked, avoiding needless image loads behind the lock surface.
    property bool locked: false

    readonly property int _intervalValue: {
        const id = UserSettings.wallpaperRotateInterval;
        const opts = UserSettings.wallpaperRotateOptions;
        for (let i = 0; i < opts.length; i++)
            if (opts[i].id === id) return opts[i].ms;
        return 0;
    }
    readonly property bool _enabled: root._intervalValue > 0

    function _pickNext() {
        const list = WallpaperScanner.paths;
        if (list.length === 0) return "";
        if (list.length === 1) return list[0];
        const current = UserSettings.wallpaperPath;
        let pick;
        do {
            pick = list[Math.floor(Math.random() * list.length)];
        } while (pick === current);
        return pick;
    }

    // Prime the scanner if rotation is enabled before the Wall tab has
    // ever been opened — otherwise paths would stay empty and the timer
    // would idle forever.
    Connections {
        target: UserSettings
        function onWallpaperRotateIntervalChanged() {
            if (root._enabled && !WallpaperScanner.loaded)
                WallpaperScanner.scan();
        }
    }

    Timer {
        id: rotateTimer
        interval: root._intervalValue
        repeat: true
        running: root._enabled
              && !root.locked
              && WallpaperScanner.paths.length > 1
        onTriggered: {
            const path = root._pickNext();
            if (path) ShellActions.setWallpaper(path);
        }
    }
}
