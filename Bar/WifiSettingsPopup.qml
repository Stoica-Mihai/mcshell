import QtQuick
import qs.Widgets

CheckRowsPopup {
    headerText: "Show on WiFi card"
    rows: [
        { kind: "check", setting: "wifiCardSignal",   label: "Signal strength" },
        { kind: "check", setting: "wifiCardSecurity", label: "Security type" },
        { kind: "check", setting: "wifiCardStatus",   label: "Connection status" },
        { kind: "check", setting: "wifiCardBand",     label: "Band (2.4 / 5 / 6 GHz)" },
        { kind: "check", setting: "wifiCardChannel",  label: "Channel" },
        { kind: "check", setting: "wifiCardBssid",    label: "BSSID (AP MAC)" },
        { kind: "check", setting: "wifiCardBitrate",  label: "Link bitrate" }
    ]
}
