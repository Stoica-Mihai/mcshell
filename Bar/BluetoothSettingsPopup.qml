import QtQuick
import qs.Widgets

CheckRowsPopup {
    headerText: "Show on Bluetooth card"
    rows: [
        { kind: "check", setting: "bluetoothCardType",    label: "Device type" },
        { kind: "check", setting: "bluetoothCardStatus",  label: "Connection status" },
        { kind: "check", setting: "bluetoothCardBattery", label: "Battery level" },
        { kind: "check", setting: "bluetoothCardAddress", label: "MAC address" },
        { kind: "check", setting: "bluetoothCardRssi",    label: "Signal (RSSI)" },
        { kind: "check", setting: "bluetoothCardClass",   label: "Class-of-Device" }
    ]
}
