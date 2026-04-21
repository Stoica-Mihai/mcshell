pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Disk-backed thumbnail cache for large image libraries.
//
// Why: Loading a 4K source image into Qt and asking for sourceSize.height=240
// still forces Qt to decode the full 4K PNG/JPEG into memory before scaling.
// Pre-generating ~240p JPEGs on disk means Image decodes a ~40KB file instead
// of the 4K source — faster, lower peak memory, no cache-keeper needed.
//
// Usage:
//   ThumbnailCache.ensureBatch(paths)         // fire-and-forget; idempotent
//   const url = ThumbnailCache.sourceFor(src) // returns file:// thumb URL,
//                                             // or file:// source as fallback
//                                             // until the thumb lands on disk
//
// Requires `magick` (ImageMagick) in PATH. Serial generation keeps CPU load
// predictable and avoids swamping low-core systems.
Singleton {
    id: root

    readonly property string cacheDir: {
        const xdg = Quickshell.env("XDG_CACHE_HOME");
        const home = Quickshell.env("HOME");
        return (xdg && xdg.length > 0 ? xdg : home + "/.cache") + "/mcshell/thumbs";
    }
    readonly property int thumbHeight: 240
    readonly property int jpegQuality: 85

    // Flips true after the first ensureBatch completes. Delegates can bind on
    // this to switch from source-path fallback to thumb path once ready.
    property bool ready: false
    property int batchProgress: 0
    property int batchTotal: 0

    signal batchComplete()

    // Returns a file:// URL to use as Image.source. Prefers the cached thumb
    // if it exists; otherwise falls back to the raw source. Qt loads the tiny
    // thumb when present, the full source otherwise — still correct, just
    // slower until the cache warms.
    function sourceFor(srcPath) {
        if (!srcPath) return "";
        if (root.ready) return "file://" + _thumbPath(srcPath);
        return "file://" + srcPath;
    }

    // Spawns a batch shell script that generates any missing thumbnails in
    // parallel. Safe to call repeatedly — pre-existing thumbs are skipped by
    // a `-f` test in the shell loop. Overlapping calls are dropped while a
    // previous batch is still running.
    function ensureBatch(paths) {
        if (!paths || paths.length === 0) {
            root.ready = true;
            root.batchComplete();
            return;
        }
        if (_batch.running) return;
        root.batchTotal = paths.length;
        root.batchProgress = 0;
        _batch.command = ["sh", "-c", _buildScript(paths)];
        _batch.running = true;
    }

    function _thumbPath(srcPath) {
        const key = Qt.md5(srcPath).substring(0, 16);
        return root.cacheDir + "/" + key + ".jpg";
    }

    // Emits one "ok" line per generated-or-already-present file so the
    // outer Process can count progress. Skips existing thumbs cheaply.
    function _buildScript(paths) {
        const lines = [
            "mkdir -p " + _shellQuote(root.cacheDir),
            ""
        ];
        for (let i = 0; i < paths.length; i++) {
            const src = paths[i];
            const dest = _thumbPath(src);
            lines.push(
                "if [ ! -f " + _shellQuote(dest) + " ]; then",
                "  magick " + _shellQuote(src)
                    + " -thumbnail x" + root.thumbHeight
                    + " -quality " + root.jpegQuality
                    + " " + _shellQuote(dest) + " 2>/dev/null",
                "fi",
                "echo ok"
            );
        }
        return lines.join("\n");
    }

    function _shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    Process {
        id: _batch
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (line === "ok") root.batchProgress++;
            }
        }
        onExited: (code, status) => {
            root.ready = true;
            root.batchComplete();
        }
    }
}
