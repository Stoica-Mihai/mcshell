import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.Config

// Per-application volume controls.
// Shows a compact slider + mute button for each active audio stream.
Item {
    id: root

    // Collect audio streams: nodes that are streams with audio, excluding sinks
    readonly property var appStreams: {
        if (!Pipewire.ready) return [];
        var streams = [];
        var nodes = Pipewire.nodes.values;
        for (var i = 0; i < nodes.length; i++) {
            var node = nodes[i];
            if (node && node.isStream && node.audio) {
                // Filter out quickshell's own streams
                var name = node.name || "";
                var mediaName = (node.properties && node.properties["media.name"]) || "";
                if (name === "quickshell" || mediaName === "quickshell") continue;
                streams.push(node);
            }
        }
        return streams;
    }

    readonly property bool hasStreams: appStreams.length > 0

    // Keep bindings alive for all tracked stream nodes
    PwObjectTracker {
        objects: root.appStreams
    }

    implicitWidth: parent ? parent.width : 240
    implicitHeight: hasStreams ? col.implicitHeight : 0
    visible: hasStreams

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 6

        // "Apps" header
        Text {
            text: "Apps"
            color: Theme.fgDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.topMargin: 2
        }

        // One row per app stream
        Repeater {
            model: root.appStreams

            delegate: Item {
                id: streamDelegate

                required property var modelData

                readonly property var node: modelData
                readonly property string appName: {
                    if (!node || !node.properties) return node?.name ?? "Unknown";
                    return node.properties["application.name"]
                        || node.description
                        || node.name
                        || "Unknown";
                }
                readonly property real rawVolume: node?.audio?.volume ?? 0
                readonly property bool muted: node?.audio?.muted ?? false

                Layout.fillWidth: true
                implicitWidth: parent ? parent.width : 240
                implicitHeight: appSlider.implicitHeight

                ControlSlider {
                    id: appSlider
                    anchors.left: parent.left
                    anchors.right: parent.right
                    label: streamDelegate.appName
                    value: streamDelegate.rawVolume
                    muted: streamDelegate.muted
                    trackHeight: 4
                    knobSize: 12
                    iconSize: 14
                    icon: streamDelegate.muted       ? "\uf466"
                        : streamDelegate.rawVolume < 0.3 ? "\uf026"
                        : streamDelegate.rawVolume < 0.7 ? "\uf027"
                        :                                  "\uf028"
                    onMoved: newValue => {
                        if (streamDelegate.node?.audio)
                            streamDelegate.node.audio.volume = newValue;
                    }
                    onIconClicked: {
                        if (streamDelegate.node?.audio)
                            streamDelegate.node.audio.muted = !streamDelegate.node.audio.muted;
                    }
                }
            }
        }
    }
}
