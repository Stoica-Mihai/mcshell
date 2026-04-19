import QtQuick
import Quickshell.Services.Pipewire

// Data-only: discovers PipeWire app-playback audio streams.
// UI components bind to `streams` and `hasStreams`.
Item {
    id: root

    readonly property var streams: {
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
    readonly property bool hasStreams: streams.length > 0

    PwObjectTracker {
        objects: root.streams
    }
}
