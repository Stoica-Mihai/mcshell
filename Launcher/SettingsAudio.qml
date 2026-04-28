import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.Config
import qs.Core
import qs.Widgets

// Audio settings card content — output/input device selection + volume.
SettingsPanel {
    id: root

    // PipeWire sample rates the active sink reports as supported, plus
    // an "Auto" entry that clears clock.force-rate. Falls back to a
    // common-rate list while the sink hasn't enumerated yet.
    readonly property var _allRates: [0, 44100, 48000, 88200, 96000, 176400, 192000, 352800, 384000]
    function _rateLabel(hz) {
        if (hz === 0) return "Auto";
        return (hz / 1000).toFixed(hz % 1000 === 0 ? 0 : 1) + " kHz";
    }
    readonly property var _supportedSet: defaultSink?.audio?.supportedRates ?? []
    readonly property var _rateValues: {
        if (_supportedSet.length === 0) return _allRates;
        const out = [0];
        for (let i = 0; i < _supportedSet.length; i++) out.push(_supportedSet[i]);
        return out;
    }
    readonly property var _rateLabels: _rateValues.map(_rateLabel)

    SafeProcess {
        id: rateProc
        failMessage: "Failed to set PipeWire clock.force-rate"
    }

    function applyForceRate() {
        rateProc.command = ["pw-metadata", "-n", "settings", "0",
            "clock.force-rate", UserSettings.audioForceRate.toString()];
        rateProc.running = true;
    }

    Component.onCompleted: applyForceRate()

    // ── Header ──
    readonly property string headerIcon: Theme.iconVolHigh
    readonly property string headerTitle: "Audio"
    readonly property string panelLegend: Theme.legend(Theme.hintUpDown, Theme.hintAdjust, Theme.hintEnter + " select", Theme.hintBack)
    readonly property string headerSubtitle: `${defaultSink?.description ?? "No output"}${Theme.separator}${volume}%`
    readonly property color headerColor: Theme.accent

    // ── Output sinks ──
    readonly property var outputNodes: {
        if (!Pipewire.ready) return [];
        const nodes = Pipewire.nodes.values;
        const sinks = [];
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i];
            if (n.isSink && !n.isStream && n.audio)
                sinks.push(n);
        }
        return sinks;
    }

    readonly property var inputNodes: {
        if (!Pipewire.ready) return [];
        const nodes = Pipewire.nodes.values;
        const sources = [];
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i];
            if (!n.isSink && !n.isStream && n.audio)
                sources.push(n);
        }
        return sources;
    }

    readonly property PwNode defaultSink: Pipewire.ready ? Pipewire.defaultAudioSink : null
    readonly property PwNode defaultSource: Pipewire.ready ? Pipewire.defaultAudioSource : null
    readonly property int volume: Math.round((defaultSink?.audio?.volume ?? 0) * 100)

    PwObjectTracker { objects: root.defaultSink ? [root.defaultSink] : [] }

    // Item 0 = volume bar, 1 = sample rate, 2..N+1 = outputs, N+2..M+1 = inputs
    itemCount: 2 + outputNodes.length + inputNodes.length
    readonly property bool volumeSelected: selectedItem === 0
    readonly property bool rateSelected: selectedItem === 1
    readonly property int _rateIndex: Math.max(0, _rateValues.indexOf(UserSettings.audioForceRate))

    function _cycleRate(dir) {
        const next = (_rateIndex + dir + _rateValues.length) % _rateValues.length;
        UserSettings.audioForceRate = _rateValues[next];
        applyForceRate();
    }

    function adjustLeft() {
        if (volumeSelected && defaultSink && defaultSink.audio) {
            defaultSink.audio.volume = Math.max(0, defaultSink.audio.volume - Theme.volumeStep);
            return true;
        }
        if (rateSelected) { _cycleRate(-1); return true; }
        return false;
    }
    function adjustRight() {
        if (volumeSelected && defaultSink && defaultSink.audio) {
            defaultSink.audio.volume = Math.min(1, defaultSink.audio.volume + Theme.volumeStep);
            return true;
        }
        if (rateSelected) { _cycleRate(1); return true; }
        return false;
    }

    function activateItem() {
        if (selectedItem <= 1) return;
        const outIdx = selectedItem - 2;
        if (outIdx < outputNodes.length) {
            Pipewire.preferredDefaultAudioSink = outputNodes[outIdx];
        } else {
            const idx = outIdx - outputNodes.length;
            if (idx < inputNodes.length)
                Pipewire.preferredDefaultAudioSource = inputNodes[idx];
        }
    }

    // Volume bar
    SettingsRow {
        id: volumeRow
        selected: root.active && root.volumeSelected

        SettingsRow.Icon {
            text: Theme.volumeIcon(root.volume / 100, root.defaultSink?.audio?.muted ?? false)
            color: (root.defaultSink?.audio?.muted ?? false) ? Theme.red : Theme.accent
        }
        SettingsProgressBar {
            value: root.volume / 100
            barColor: (root.defaultSink?.audio?.muted ?? false) ? Theme.red : Theme.accent
        }
        SettingsRow.Value { text: root.volume + "%"; Layout.preferredWidth: 30 }
    }

    // Sample rate (PipeWire clock.force-rate)
    SettingsRow {
        id: rateRow
        selected: root.active && root.rateSelected

        SettingsRow.Icon { text: ""; color: Theme.accent }
        SettingsRow.Label { text: "Sample rate"; Layout.fillWidth: true }
        CyclePicker {
            pillValue: true
            model: root._rateLabels
            currentIndex: root._rateIndex
            onIndexChanged: idx => {
                UserSettings.audioForceRate = root._rateValues[idx];
                root.applyForceRate();
            }
        }
    }

    Separator { topMargin: 4 }

    // Output section
    SectionHeader { label: "OUTPUT" }

    Repeater {
        id: outputRepeater
        model: root.outputNodes
        delegate: SelectionRow {
            required property var modelData
            required property int index
            selected: root.active && root.selectedItem === (index + 2)
            label: modelData.description || modelData.name || "Unknown"
            isCurrent: modelData === root.defaultSink
        }
    }

    Separator { topMargin: 2 }

    // Input section
    SectionHeader { label: "INPUT" }

    Repeater {
        id: inputRepeater
        model: root.inputNodes
        delegate: SelectionRow {
            required property var modelData
            required property int index
            selected: root.active && root.selectedItem === (2 + root.outputNodes.length + index)
            label: modelData.description || modelData.name || "Unknown"
            isCurrent: modelData === root.defaultSource
        }
    }
}
