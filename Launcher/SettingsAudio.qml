import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.Config

// Audio settings card content — output/input device selection + volume.
SettingsPanel {
    id: root

    // ── Header ──
    readonly property string headerIcon: Theme.iconVolHigh
    readonly property string headerTitle: "Audio"
    readonly property string panelLegend: Theme.legend(Theme.hintUpDown, Theme.hintAdjust, Theme.hintEnter + " select", Theme.hintBack)
    readonly property string headerSubtitle: (defaultSink?.description ?? "No output") + Theme.separator + volume + "%"
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

        Text {
            text: Theme.volumeIcon(root.volume / 100, root.defaultSink?.audio?.muted ?? false)
            font.family: Theme.iconFont
            font.pixelSize: Theme.fontSizeMedium
            color: (root.defaultSink?.audio?.muted ?? false) ? Theme.red : Theme.accent
        }
        Rectangle {
            Layout.fillWidth: true
            height: 4
            radius: 2
            color: Theme.overlay
            Rectangle {
                width: parent.width * (root.volume / 100)
                height: parent.height
                radius: parent.radius
                color: (root.defaultSink?.audio?.muted ?? false) ? Theme.red : Theme.accent
            }
        }
        Text {
            text: root.volume + "%"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeTiny
            color: Theme.fgDim
            Layout.preferredWidth: 30
            horizontalAlignment: Text.AlignRight
        }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; Layout.topMargin: 4 }

    // Output section
    Text {
        text: "OUTPUT"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeMini
        color: Theme.fgDim
        Layout.leftMargin: 12
        Layout.topMargin: 2
        opacity: Theme.opacitySubtle
    }

    Repeater {
        id: outputRepeater
        model: root.outputNodes
        delegate: SettingsRow {
            required property var modelData
            required property int index
            selected: root.active && root.selectedItem === (index + 1)
            Layout.preferredHeight: 30

            Text {
                text: modelData === root.defaultSink ? Theme.iconCheck : ""
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSizeTiny
                color: Theme.green
                Layout.preferredWidth: 14
            }
            Text {
                text: modelData.description || modelData.name || "Unknown"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: modelData === root.defaultSink ? Theme.accent : Theme.fg
                elide: Text.ElideRight
                Layout.fillWidth: true
                maximumLineCount: 1
            }
        }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; Layout.topMargin: 2 }

    // Input section
    Text {
        text: "INPUT"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeMini
        color: Theme.fgDim
        Layout.leftMargin: 12
        Layout.topMargin: 2
        opacity: Theme.opacitySubtle
    }

    Repeater {
        id: inputRepeater
        model: root.inputNodes
        delegate: SettingsRow {
            required property var modelData
            required property int index
            selected: root.active && root.selectedItem === (1 + root.outputNodes.length + index)
            Layout.preferredHeight: 30

            Text {
                text: modelData === root.defaultSource ? Theme.iconCheck : ""
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSizeTiny
                color: Theme.green
                Layout.preferredWidth: 14
            }
            Text {
                text: modelData.description || modelData.name || "Unknown"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: modelData === root.defaultSource ? Theme.accent : Theme.fg
                elide: Text.ElideRight
                Layout.fillWidth: true
                maximumLineCount: 1
            }
        }
    }
}
