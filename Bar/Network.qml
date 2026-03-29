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
            font.family: "Symbols Nerd Font"
            font.pixelSize: Theme.iconSize
            color: root.status === "connected" ? Theme.fg : Theme.red
            text: {
                if (root.status !== "connected") return "\uf467";     // 󰤭 disconnected
                if (root.type === "wifi") {
                    if (root.wifiSignal > 75) return "\uf1eb";        //  strong
                    if (root.wifiSignal > 50) return "\uf1eb";        //  medium
                    if (root.wifiSignal > 25) return "\uf1eb";        //  weak
                    return "\uf1eb";                                   //  minimal
                }
                return "\u{f09e9}";                                    // 󰧩 ethernet
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
