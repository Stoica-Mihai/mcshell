import QtQuick
import QtQuick.Layouts
import qs.Config

// Status hint shown below device cards in WiFi/Bluetooth categories.
// Maps a StatusTracker's state to colored text with status-specific labels.
Text {
    id: root

    required property StatusTracker tracker
    required property string targetId
    property var successStatuses: []
    property var neutralStatuses: []
    property var statusLabels: ({})
    property string defaultText: ""

    readonly property bool isTarget: tracker.targetId === root.targetId
    readonly property string activeStatus: isTarget ? tracker.status : ""

    Layout.alignment: Qt.AlignHCenter
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSizeSmall

    color: activeStatus === "failed" ? Theme.red
         : successStatuses.indexOf(activeStatus) >= 0 ? Theme.green
         : neutralStatuses.indexOf(activeStatus) >= 0 ? Theme.fgDim
         : activeStatus !== "" ? Theme.accent
         : Theme.fgDim

    opacity: activeStatus !== "" ? 1.0 : Theme.opacitySubtle

    text: activeStatus !== "" && statusLabels[activeStatus] !== undefined
        ? statusLabels[activeStatus]
        : defaultText
}
