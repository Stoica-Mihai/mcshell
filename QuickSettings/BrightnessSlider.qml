import QtQuick
import Quickshell.Io
import qs.Config
import qs.Core

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

    SafeProcess {
        id: getMax
        command: ["brightnessctl", "max"]
        failMessage: "brightnessctl not found — brightness control unavailable"
        onRead: data => {
            const val = parseInt(data.trim(), 10);
            if (!isNaN(val) && val > 0) root.maxBrightness = val;
        }
    }

    SafeProcess {
        id: getCurrent
        command: ["brightnessctl", "get"]
        failMessage: "brightnessctl get failed"
        onRead: data => {
            if (slider.dragging) return;
            const val = parseInt(data.trim(), 10);
            if (!isNaN(val)) root.currentBrightness = val;
        }
    }

    SafeProcess {
        id: setBrt
        command: ["brightnessctl", "set", "100%"]
        failMessage: "brightnessctl set failed"
    }

    ControlSlider {
        id: slider
        anchors.left: parent.left
        anchors.right: parent.right
        label: "Brightness"
        icon: Theme.iconBrightness
        value: root.fraction
        accentColor: Theme.yellow
        onMoved: newValue => root.setBrightness(newValue)
    }
}
