import QtQuick
import Quickshell.Io
import qs.Config

Item {
    id: root

    property int currentBrightness: 0
    property int maxBrightness: 1
    readonly property real fraction: maxBrightness > 0
        ? currentBrightness / maxBrightness : 0

    implicitWidth: parent ? parent.width : 240
    implicitHeight: slider.implicitHeight

    function refresh() {
        getMax.running = true;
        getCurrent.running = true;
    }

    function setBrightness(frac) {
        const pct = Math.round(Math.max(0, Math.min(1, frac)) * 100);
        root.currentBrightness = Math.round(pct * root.maxBrightness / 100);
        setBrt.command = ["brightnessctl", "set", pct + "%"];
        setBrt.running = true;
    }

    Process {
        id: getMax
        command: ["brightnessctl", "max"]
        stdout: SplitParser {
            onRead: data => {
                const val = parseInt(data.trim(), 10);
                if (!isNaN(val) && val > 0) root.maxBrightness = val;
            }
        }
    }

    Process {
        id: getCurrent
        command: ["brightnessctl", "get"]
        stdout: SplitParser {
            onRead: data => {
                if (slider.dragging) return;
                const val = parseInt(data.trim(), 10);
                if (!isNaN(val)) root.currentBrightness = val;
            }
        }
    }

    Process {
        id: setBrt
        property var command: ["brightnessctl", "set", "100%"]
    }

    ControlSlider {
        id: slider
        anchors.left: parent.left
        anchors.right: parent.right
        label: "Brightness"
        icon: "\uf185"
        value: root.fraction
        accentColor: Theme.yellow
        onMoved: newValue => root.setBrightness(newValue)
    }
}
