import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.Config
import qs.Widgets

// Per-application volume controls (UI only).
// Data comes from AppStreamProvider.
Item {
    id: root

    // Data source — filtering logic lives there, not here
    AppStreamProvider {
        id: provider
    }

    readonly property bool hasStreams: provider.hasStreams

    implicitWidth: parent ? parent.width : 240
    implicitHeight: hasStreams ? col.implicitHeight : 0
    visible: hasStreams

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 6

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

        Repeater {
            model: provider.streams

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
                    icon: Theme.volumeIcon(streamDelegate.rawVolume, streamDelegate.muted)
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
