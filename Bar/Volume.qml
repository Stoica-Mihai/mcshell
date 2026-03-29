import QtQuick
import Quickshell.Services.Pipewire
import qs.Config

// Volume state provider — PipeWire bindings only.
// UI is handled by SystemCapsule in StatusBar.
Item {
    id: root

    // ── PipeWire native binding ─────────────────────────
    readonly property PwNode sink: Pipewire.ready ? Pipewire.defaultAudioSink : null
    readonly property real rawVolume: sink?.audio?.volume ?? 0
    readonly property int volume: Math.round(rawVolume * 100)
    readonly property bool muted: sink?.audio?.muted ?? false

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    function setVolume(vol) {
        if (!sink?.audio) return;
        sink.audio.volume = Math.max(0, Math.min(1.0, vol));
    }

    function toggleMute() {
        if (!sink?.audio) return;
        sink.audio.muted = !sink.audio.muted;
    }
}
