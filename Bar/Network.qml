import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import qs.Config

Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // ── Reactive network state (no polling) ─────────────
    readonly property var connectedDevice: {
        const devs = Networking.devices?.values ?? [];
        for (let i = 0; i < devs.length; i++) {
            if (devs[i].connected) return devs[i];
        }
        return null;
    }

    readonly property bool isConnected: connectedDevice !== null
    readonly property bool isWifi: connectedDevice?.type === DeviceType.Wifi
    readonly property bool isEthernet: connectedDevice?.type === DeviceType.Ethernet

    readonly property string name: {
        if (!isWifi || !connectedDevice) return "";
        const nets = connectedDevice.networks?.values ?? [];
        for (let i = 0; i < nets.length; i++) {
            if (nets[i].connected) return nets[i].name;
        }
        return "";
    }

    readonly property int wifiSignal: {
        if (!isWifi || !connectedDevice) return 0;
        const nets = connectedDevice.networks?.values ?? [];
        for (let i = 0; i < nets.length; i++) {
            if (nets[i].connected) return Math.round(nets[i].signalStrength * 100);
        }
        return 0;
    }

    // ── UI ──────────────────────────────────────────────
    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Text {
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSize
            color: root.isConnected ? Theme.fg : Theme.red
            text: {
                if (!root.isConnected) return Theme.iconNetOff;
                if (root.isWifi) return Theme.iconWifi;
                return Theme.iconEthernet;
            }
        }

        Text {
            visible: root.isWifi && root.isConnected
            color: Theme.fgDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            text: root.name
        }
    }
}
