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

    // ── Auto-switch to newly-connected output (opt-in) ──
    // Armed a moment after the initial Pipewire sync so the startup burst of
    // node inserts doesn't trigger a switch — only genuine hotplugs do.
    property bool _armed: false
    Timer {
        id: _armTimer
        interval: 1500
        onTriggered: root._armed = true
    }
    Connections {
        target: Pipewire
        function onReadyChanged() { if (Pipewire.ready) _armTimer.restart(); }
    }
    Component.onCompleted: if (Pipewire.ready) _armTimer.restart();

    Connections {
        target: Pipewire.nodes
        function onObjectInsertedPost(object, index) {
            if (!root._armed || !UserSettings.audioAutoSwitch) return;
            if (!object || !object.isSink || object.isStream || !object.audio) return;
            if (UserSettings.audioSinkHidden(object.name)) return;
            Pipewire.setDefaultAudioSink(object);
            NotificationDispatcher.send("Audio",
                "Switched to " + (object.description || object.name || "new device"),
                Theme.notifShort);
        }
    }

    // A hidden sink must never be the default — if it becomes one (e.g.
    // WirePlumber's fallback after the active device disconnects), redirect
    // to the first non-hidden output. Independent of audioAutoSwitch:
    // hiding a sink is itself the opt-in.
    function _redirectIfHidden() {
        if (!root._armed) return;
        // Read the default's name as a string — Qt 6.11 returns undefined for
        // .name on a PwNode received from defaultAudioSink (mcs-qs property).
        const name = Pipewire.defaultSinkName;
        if (!name || !UserSettings.audioSinkHidden(name)) return;
        const ns = Pipewire.nodes.values;
        for (let i = 0; i < ns.length; i++) {
            const n = ns[i];
            if (n.isSink && !n.isStream && n.audio && !UserSettings.audioSinkHidden(n.name)) {
                Pipewire.setDefaultAudioSink(n);
                return;
            }
        }
    }
    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() { root._redirectIfHidden(); }
    }
}
