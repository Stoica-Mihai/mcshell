import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.Config

// Audio settings card content — output/input device selection + volume.
// Placed inside a CarouselStrip expanded view.
Item {
    id: root

    property bool active: false

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

    // ── Selected item for keyboard nav ──
    property int selectedItem: 0
    readonly property int totalItems: outputNodes.length + inputNodes.length

    function navigateUp() {
        if (selectedItem > 0) selectedItem--;
        ensureVisible();
    }
    function navigateDown() {
        if (selectedItem < totalItems - 1) selectedItem++;
        ensureVisible();
    }

    // Scroll Flickable to keep the selected item visible
    function ensureVisible() {
        // Each item is ~30px high, offset by header (~120px)
        const headerH = 120;
        const itemH = 30;
        const targetY = headerH + selectedItem * itemH;
        if (targetY < audioFlick.contentY + headerH)
            audioFlick.contentY = Math.max(0, targetY - headerH);
        else if (targetY + itemH > audioFlick.contentY + audioFlick.height)
            audioFlick.contentY = targetY + itemH - audioFlick.height;
    }
    function activateItem() {
        if (selectedItem < outputNodes.length) {
            Pipewire.preferredDefaultAudioSink = outputNodes[selectedItem];
        } else {
            const idx = selectedItem - outputNodes.length;
            if (idx < inputNodes.length)
                Pipewire.preferredDefaultAudioSource = inputNodes[idx];
        }
    }

    Flickable {
        id: audioFlick
        anchors.fill: parent
        anchors.margins: 14
        contentHeight: audioCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                audioFlick.contentY = Math.max(0,
                    Math.min(audioFlick.contentHeight - audioFlick.height,
                             audioFlick.contentY - event.angleDelta.y * 1.5));
            }
        }
    ColumnLayout {
        id: audioCol
        width: parent.width
        spacing: 4

        // Icon + title (fixed, not scrollable)
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "\uf028"
            font.family: Theme.iconFont
            font.pixelSize: 28
            color: Theme.accent
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Audio"
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.bold: true
            color: Theme.fg
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: parent.width - 24
            text: (root.defaultSink?.description ?? "No output") + " • " + root.volume + "%"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.fgDim
            elide: Text.ElideRight
        }

        // Volume bar
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            spacing: 8

            Text {
                text: Theme.volumeIcon(root.volume / 100, root.defaultSink?.audio?.muted ?? false)
                font.family: Theme.iconFont
                font.pixelSize: 14
                color: (root.defaultSink?.audio?.muted ?? false) ? Theme.red : Theme.accent
            }
            Rectangle {
                Layout.fillWidth: true
                height: 4
                radius: 2
                color: Qt.rgba(1,1,1,0.06)
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
                font.pixelSize: 10
                color: Theme.fgDim
                Layout.preferredWidth: 30
                horizontalAlignment: Text.AlignRight
            }
        }

        // Separator
        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; Layout.topMargin: 4 }

        // Output section
        Text {
            text: "OUTPUT"
            font.family: Theme.fontFamily
            font.pixelSize: 9
            color: Theme.fgDim
            Layout.leftMargin: 12
            Layout.topMargin: 2
            opacity: 0.6
        }

        Repeater {
            model: root.outputNodes
            delegate: Rectangle {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                implicitHeight: 30
                radius: 6
                color: root.active && root.selectedItem === index
                    ? Qt.rgba(1,1,1,0.06) : "transparent"
                Layout.leftMargin: 4
                Layout.rightMargin: 4

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Text {
                        text: modelData === root.defaultSink ? Theme.iconCheck : ""
                        font.family: Theme.iconFont
                        font.pixelSize: 10
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
        }

        // Separator
        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; Layout.topMargin: 2 }

        // Input section
        Text {
            text: "INPUT"
            font.family: Theme.fontFamily
            font.pixelSize: 9
            color: Theme.fgDim
            Layout.leftMargin: 12
            Layout.topMargin: 2
            opacity: 0.6
        }

        Repeater {
            model: root.inputNodes
            delegate: Rectangle {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                implicitHeight: 30
                radius: 6
                color: root.active && root.selectedItem === (root.outputNodes.length + index)
                    ? Qt.rgba(1,1,1,0.06) : "transparent"
                Layout.leftMargin: 4
                Layout.rightMargin: 4

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Text {
                        text: modelData === root.defaultSource ? Theme.iconCheck : ""
                        font.family: Theme.iconFont
                        font.pixelSize: 10
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

    }
    }
}
