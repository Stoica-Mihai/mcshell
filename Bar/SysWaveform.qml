import QtQuick
import Qs.SysInfo
import qs.Config
import qs.Widgets

// Tiny 8-bar waveform showing CPU core load inside the capsule.
// Each bar represents 2 cores (averaged). Height = load, color = severity.
// Hover shows a one-line tooltip; click toggles the sysinfo dropdown.
Item {
    id: root

    signal clicked()

    readonly property bool hovered: mouse.containsMouse
    property bool active: false

    implicitWidth: wave.implicitWidth
    implicitHeight: Theme.iconSize

    Row {
        id: wave
        anchors.centerIn: parent
        spacing: 1.5

        Repeater {
            model: 8

            Rectangle {
                width: 2.5
                radius: 1
                anchors.bottom: parent.bottom

                readonly property real _avg: {
                    const cores = SysInfo.cpuCores;
                    const i0 = index * 2;
                    const i1 = i0 + 1;
                    const a = i0 < cores.length ? cores[i0] : 0;
                    const b = i1 < cores.length ? cores[i1] : 0;
                    return (a + b) / 2;
                }

                height: Math.max(2, _avg / 100 * 14)
                color: Theme.loadColor(_avg)

                Behavior on height { NumberAnimation { duration: Theme.animCarousel; easing.type: Easing.OutCubic } }
                Behavior on color  { ColorAnimation  { duration: Theme.animCarousel } }
            }
        }
    }

    ActiveUnderline { visible: root.active }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        // Wayland layer-shell surfaces can cancel the first pointer grab
        // after startup (input region settling). Fall back to press if
        // the click is lost.
        onCanceled: root.clicked()
    }

    ThemedTooltip {
        showWhen: root.hovered && !root.active
        text: root.hovered ? root._tooltipText() : ""
    }

    function _tooltipText() {
        const cpu = SysInfo.cpuPercent.toFixed(0);
        const temps = SysInfo.temperatures;
        let cpuTemp = "";
        for (let i = 0; i < temps.length; i++) {
            const lbl = temps[i].label;
            if (lbl === "Tctl" || lbl === "Package id 0") {
                cpuTemp = temps[i].value.toFixed(0) + "\u00B0";
                break;
            }
        }
        if (!cpuTemp && temps.length > 0)
            cpuTemp = temps[0].value.toFixed(0) + "\u00B0";
        const mem = SysInfo.memPercent.toFixed(0);
        return `CPU ${cpu}%` + (cpuTemp ? ` \u00B7 ${cpuTemp}` : "") + ` \u00B7 ${mem}% RAM`;
    }
}
