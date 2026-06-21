pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Config

// Single source of truth for default-audio-sink volume/mute state (PipeWire
// bindings only). One tracker + one binding set shell-wide so N monitors
// don't each pin the sink and race mutating writes. UI lives in StatusBar.
Singleton {
    id: root

    // QtObject (not PwNode) so the binding can hold null while
    // Pipewire.ready is still false at startup. PwNode would trigger a
    // QML type-check warning on every shell start.
    readonly property QtObject sink: Pipewire.ready ? Pipewire.defaultAudioSink : null
    readonly property real rawVolume: sink?.audio?.volume ?? 0
    readonly property int volume: Theme.percent(rawVolume)
    readonly property bool muted: sink?.audio?.muted ?? false
    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    function setVolume(vol) {
        if (!sink?.audio) return;
        sink.audio.volume = Theme.clamp01(vol);
    }

    function toggleMute() {
        if (!sink?.audio) return;
        sink.audio.muted = !sink.audio.muted;
    }
}
