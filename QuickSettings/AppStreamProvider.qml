import QtQuick
import Quickshell.Services.Pipewire

// Data-only: discovers and filters PipeWire audio streams.
// UI components bind to `streams` and `hasStreams`.
// Filtering logic lives here — changing it cannot affect layout.
Item {
    id: root

    // Output: filtered list of streams for the UI to consume
    readonly property var streams: filteredStreams
    readonly property bool hasStreams: filteredStreams.length > 0

    // ── Raw stream collection (reactive via PipeWire) ───
    readonly property var rawStreams: {
        if (!Pipewire.ready) return [];
        const result = [];
        const nodes = Pipewire.nodes.values;
        for (let i = 0; i < nodes.length; i++) {
            const node = nodes[i];
            // isSink: playback streams (apps outputting audio)
            if (node && node.isStream && node.audio && node.isSink)
                result.push(node);
        }
        return result;
    }

    // ── Filtering (add rules here without touching UI) ──
    readonly property var filteredStreams: {
        const result = [];
        for (let i = 0; i < rawStreams.length; i++) {
            const node = rawStreams[i];
            if (shouldShow(node))
                result.push(node);
        }
        return result;
    }

    function shouldShow(node) {
        return true;
    }

    // Keep PipeWire bindings alive
    PwObjectTracker {
        objects: root.rawStreams
    }
}
