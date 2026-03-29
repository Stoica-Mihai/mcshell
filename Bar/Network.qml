import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Config
import qs.Widgets

Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    property string status: "disconnected"  // connected, disconnected, connecting
    property string type: "ethernet"        // ethernet, wifi
    property string name: ""
    property int wifiSignal: 0

    // ── Poll network state ──────────────────────────────
    PolledProcess {
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE,CONNECTION device 2>/dev/null | grep -m1 '^\\(ethernet\\|wifi\\):connected' || echo 'none:disconnected:'"]
        interval: 5000
        onRead: data => {
            const parts = data.trim().split(":");
            if (parts.length < 3) return;

            const devType = parts[0];
            const state = parts[1];

            if (devType === "none" || !state.startsWith("connected")) {
                root.status = "disconnected";
                root.name = "";
            } else {
                root.type = devType;
                root.status = "connected";
                root.name = parts.slice(2).join(":");
            }
        }
    }

    // Wifi signal strength (only when on wifi)
    PolledProcess {
        command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL", "device", "wifi", "list"]
        interval: 5000
        active: root.type === "wifi"
        onRead: data => {
            for (const line of data.trim().split("\n")) {
                if (line.startsWith("*:")) {
                    root.wifiSignal = parseInt(line.split(":")[1]) || 0;
                    break;
                }
            }
        }
    }

    // ── UI ──────────────────────────────────────────────
    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Text {
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSize
            color: root.status === "connected" ? Theme.fg : Theme.red
            text: {
                if (root.status !== "connected") return Theme.iconNetOff;
                if (root.type === "wifi") return Theme.iconWifi;
                return Theme.iconEthernet;
            }
        }

        Text {
            visible: root.type === "wifi" && root.status === "connected"
            color: Theme.fgDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            text: root.name
        }
    }
}
