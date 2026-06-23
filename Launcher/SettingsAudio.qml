import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.Config
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

    function applyForceRate() {
        Pipewire.setForceRate(UserSettings.audioForceRate);
    }

    Component.onCompleted: applyForceRate()

    // ── Header ──
    readonly property string headerIcon: Theme.iconVolHigh
    readonly property string headerTitle: "Audio"
    readonly property string panelLegend: Theme.legend(Theme.hintUpDown, Theme.hintAdjust, Theme.hintEnter + " select", Theme.hintBack)
    readonly property string headerSubtitle: `${Pipewire.defaultSinkName || "No output"}${Theme.separator}${volume}%`
    readonly property color headerColor: Theme.accent

    // ── Selectable audio devices — non-stream audio nodes, partitioned by isSink ──
    function _audioNodes(wantSink) {
        if (!Pipewire.ready) return [];
        const nodes = Pipewire.nodes.values;
        const out = [];
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i];
            if (n.isSink === wantSink && !n.isStream && n.audio)
                out.push(n);
        }
        return out;
    }
    readonly property var outputNodes: _audioNodes(true)
    readonly property var inputNodes: _audioNodes(false)

    // QtObject (not PwNode) so the binding can hold null while Pipewire.ready
    // is still false — a PwNode-typed nullable binding fails the QML type
    // check and leaves the sink unbound, reading volume as 0.
    readonly property QtObject defaultSink: Pipewire.ready ? Pipewire.defaultAudioSink : null
    readonly property QtObject defaultSource: Pipewire.ready ? Pipewire.defaultAudioSource : null
    readonly property int volume: Theme.percent(defaultSink?.audio?.volume ?? 0)

    PwObjectTracker { objects: root.defaultSink ? [root.defaultSink] : [] }

    // Item 0 = volume, 1 = sample rate, 2 = auto-switch, 3.. = outputs then inputs
    itemCount: 3 + outputNodes.length + inputNodes.length
    readonly property bool volumeSelected: selectedItem === 0
    readonly property bool rateSelected: selectedItem === 1
    readonly property bool autoSwitchSelected: selectedItem === 2

    function _flipAutoSwitch() {
        UserSettings.audioAutoSwitch = !UserSettings.audioAutoSwitch;
        return true;
    }
    readonly property int _rateIndex: Math.max(0, _rateValues.indexOf(UserSettings.audioForceRate))

    function _cycleRate(dir) {
        const next = (_rateIndex + dir + _rateValues.length) % _rateValues.length;
        UserSettings.audioForceRate = _rateValues[next];
        applyForceRate();
    }

    function adjustLeft() {
        if (volumeSelected && defaultSink && defaultSink.audio) {
            defaultSink.audio.volume = Theme.clamp01(defaultSink.audio.volume - Theme.volumeStep);
            return true;
        }
        if (rateSelected) { _cycleRate(-1); return true; }
        if (autoSwitchSelected) return _flipAutoSwitch();
        if (_outputAt(selectedItem)) return _toggleHide();
        return false;
    }
    function adjustRight() {
        if (volumeSelected && defaultSink && defaultSink.audio) {
            defaultSink.audio.volume = Theme.clamp01(defaultSink.audio.volume + Theme.volumeStep);
            return true;
        }
        if (rateSelected) { _cycleRate(1); return true; }
        if (autoSwitchSelected) return _flipAutoSwitch();
        if (_outputAt(selectedItem)) return _toggleHide();
        return false;
    }

    // The output node at a given nav index, or null if it's not an output row.
    function _outputAt(item) {
        const oi = item - 3;
        return (oi >= 0 && oi < outputNodes.length) ? outputNodes[oi] : null;
    }
    function _toggleHide() {
        const n = _outputAt(selectedItem);
        if (!n || !n.name) return false;
        UserSettings.setAudioSinkHidden(n.name, !UserSettings.audioSinkHidden(n.name));
        return true;
    }

    function activateItem() {
        if (autoSwitchSelected) { _flipAutoSwitch(); return; }
        if (selectedItem <= 1) return;
        const outIdx = selectedItem - 3;
        // Use the invokable rather than assigning preferredDefaultAudioSink:
        // Qt 6.11's QML won't coerce an ObjectModel.values element (QObject*)
        // to the PwNode*-typed property. setDefaultAudioSink takes QObject*
        // and casts internally (mcs-qs addition).
        if (outIdx < outputNodes.length) {
            const n = outputNodes[outIdx];
            // Explicitly choosing a hidden sink unhides it (intent wins),
            // else the redirect-away watcher would bounce it immediately.
            if (n && n.name && UserSettings.audioSinkHidden(n.name))
                UserSettings.setAudioSinkHidden(n.name, false);
            Pipewire.setDefaultAudioSink(n);
        } else {
            const idx = outIdx - outputNodes.length;
            if (idx < inputNodes.length)
                Pipewire.setDefaultAudioSource(inputNodes[idx]);
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

    // Auto-switch to a newly-connected output device
    SelectionRow {
        selected: root.active && root.autoSwitchSelected
        label: "Auto-switch to new device"
        isCurrent: UserSettings.audioAutoSwitch

        Item {
            Layout.preferredWidth: 120
            Layout.preferredHeight: parent.height
            SkewToggle {
                anchors.centerIn: parent
                state: UserSettings.audioAutoSwitch ? 1 : 0
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
            id: outRow
            required property var modelData
            required property int index
            readonly property bool hidden: UserSettings.audioSinkHidden(modelData.name)
            selected: root.active && root.selectedItem === (index + 3)
            opacity: hidden ? Theme.opacityDim : 1.0
            label: modelData.description || modelData.name || "Unknown"
            isCurrent: modelData.name === Pipewire.defaultSinkName

            // ←/→ toggles Hidden/Shown; hidden sinks are skipped by auto-switch
            // and the default redirects away from them.
            Item {
                Layout.preferredWidth: 90
                Layout.preferredHeight: parent.height
                SkewToggle {
                    anchors.centerIn: parent
                    state: outRow.hidden ? 0 : 1
                    labels: ["Hidden", "Shown"]
                }
            }
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
            selected: root.active && root.selectedItem === (3 + root.outputNodes.length + index)
            label: modelData.description || modelData.name || "Unknown"
            isCurrent: modelData.name === Pipewire.defaultSourceName
        }
    }
}
