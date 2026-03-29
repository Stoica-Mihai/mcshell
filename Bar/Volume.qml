import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.Config

Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // Expose popup state for StatusBar click-catcher
    property bool popupVisible: volumePanel.isOpen
    function dismissPopup() { volumePanel.close(); }

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

    // ── UI ──────────────────────────────────────────────
    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Text {
            color: root.muted ? Theme.red : Theme.fg
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSize
            text: Theme.volumeIcon(root.volume / 100, root.muted)
        }

        Text {
            color: root.muted ? Theme.red : Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            text: root.volume + "%"
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: event => {
            if (event.button === Qt.MiddleButton) {
                root.toggleMute();
            } else {
                if (volumePanel.isOpen)
                    volumePanel.close();
                else {
                    volumePanel.anchor.item = root;
                    volumePanel.anchor.rect.x = -(volumePanel.implicitWidth - root.width);
                    volumePanel.anchor.rect.y = (Theme.barHeight + root.height) / 2 - 2;
                    volumePanel.open();
                }
            }
        }
        onWheel: wheel => {
            const step = 0.02;
            if (wheel.angleDelta.y > 0)
                root.setVolume(root.rawVolume + step);
            else
                root.setVolume(root.rawVolume - step);
        }
    }

    VolumePanel {
        id: volumePanel
    }
}
