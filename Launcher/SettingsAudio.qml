import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.Config
import qs.Widgets

// Audio settings card content — output/input device selection + volume.
SettingsPanel {
    id: root

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

    // Item 0 = volume bar, 1..N = outputs, N+1..M = inputs
    itemCount: 1 + outputNodes.length + inputNodes.length
    readonly property bool volumeSelected: selectedItem === 0
    function adjustLeft() {
        if (volumeSelected && defaultSink && defaultSink.audio) {
            defaultSink.audio.volume = Math.max(0, defaultSink.audio.volume - Theme.volumeStep);
            return true;
        }
        return false;
    }
    function adjustRight() {
        if (volumeSelected && defaultSink && defaultSink.audio) {
            defaultSink.audio.volume = Math.min(1, defaultSink.audio.volume + Theme.volumeStep);
            return true;
        }
        return false;
    }

    function activateItem() {
        if (selectedItem === 0) return;
        const outIdx = selectedItem - 1;
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

    Separator { topMargin: 4 }

    // Output section
    SectionHeader { label: "OUTPUT" }

    Repeater {
        id: outputRepeater
        model: root.outputNodes
        delegate: SelectionRow {
            required property var modelData
            required property int index
            selected: root.active && root.selectedItem === (index + 1)
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
            selected: root.active && root.selectedItem === (1 + root.outputNodes.length + index)
            label: modelData.description || modelData.name || "Unknown"
            isCurrent: modelData === root.defaultSource
        }
    }
}
