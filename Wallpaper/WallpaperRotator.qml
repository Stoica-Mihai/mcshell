import QtQuick
import Quickshell
import qs.Config
import qs.Core

// Auto-rotates the wallpaper on a fixed interval.
// Each targeted screen gets its own random/sequential pick.
// wallpaperRotateScreen controls which screen(s) rotate.
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

    function _pickNext(exclude) {
        const list = WallpaperScanner.paths;
        if (list.length === 0) return "";
        if (list.length === 1) return list[0];
        if (UserSettings.wallpaperRotateMode === "sequential") {
            const idx = list.indexOf(exclude);
            return list[(idx + 1) % list.length];
        }
        let pick;
        do {
            pick = list[Math.floor(Math.random() * list.length)];
        } while (pick === exclude && list.length > 1);
        return pick;
    }

    // Prime the scanner if rotation is enabled before the Wall tab has
    // ever been opened — otherwise paths would stay empty and the timer
    // would idle forever.
    Component.onCompleted: {
        if (_enabled && !WallpaperScanner.loaded)
            WallpaperScanner.scan();
    }
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
            const target = UserSettings.wallpaperRotateScreen;
            const screens = Quickshell.screens;
            const folder = UserSettings.wallpaperFolder;
            const map = UserSettings.perScreenMap;
            const batch = {};

            for (let i = 0; i < screens.length; i++) {
                const name = screens[i].name;
                if (target !== "" && target !== name) continue;
                const current = map[name]
                    ? folder + "/" + map[name]
                    : UserSettings.wallpaperPath;
                const next = root._pickNext(current);
                if (next) batch[name] = next;
            }

            if (Object.keys(batch).length > 0)
                UserSettings.setWallpapersForScreens(batch);
        }
    }
}
