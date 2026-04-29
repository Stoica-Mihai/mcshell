import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Wayland
import qs.Config
import qs.Core
import qs.Widgets

// BlueZ pairing prompt — themed overlay dialog backed by mcs-qs's
// Agent1 binding (Bluetooth.pairingAgent). Renders a kind-specific UI:
// confirmation/authorization → yes/no buttons; pinCode/passkey input
// → text field with submit/cancel; display variants → read-only.
Item {
    id: root

    // Currently active request, or null when no pairing is in flight.
    property var activeRequest: null

    Connections {
        target: Bluetooth.pairingAgent
        function onRequestReceived(req) {
            // Display variants are pure UI hints. Keep them visible briefly
            // (the agent already replied to BlueZ); for response-required
            // kinds, hold the request open for user input.
            root.activeRequest = req;
            req.answeredChanged.connect(() => {
                if (req.answered && root.activeRequest === req)
                    root.activeRequest = null;
            });
        }
        function onCancelled() { root.activeRequest = null; }
    }

    readonly property string _kind: activeRequest ? activeRequest.kind : ""
    readonly property bool _isInput: _kind === "pinCode" || _kind === "passkey"
    readonly property bool _isConfirm: _kind === "confirmation"
        || _kind === "authorization" || _kind === "serviceAuthorization"
    readonly property bool _isDisplay: _kind === "displayPinCode" || _kind === "displayPasskey"
    readonly property string _deviceLabel: {
        if (!activeRequest) return "";
        const path = activeRequest.devicePath;
        const devs = Bluetooth.devices.values;
        for (let i = 0; i < devs.length; i++) {
            if (devs[i].dbusPath === path) {
                return devs[i].name || devs[i].deviceName || devs[i].address || path;
            }
        }
        // Fallback — last path component looks like dev_XX_XX_XX_XX_XX_XX
        const last = path.split("/").pop() || path;
        return last.replace(/^dev_/, "").replace(/_/g, ":");
    }

    Variants {
        model: Quickshell.screens

        OverlayWindow {
            id: overlay
            namespace: "mcshell-btpair"
            active: root.activeRequest !== null

            required property var modelData
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }

            BackgroundEffect.blurRegion: UserSettings.blurEnabled && root.activeRequest
                ? dialogBlurRegion : null
            Region { id: dialogBlurRegion; item: dialog; radius: Theme.dialogRadius }

            Connections {
                target: root
                function onActiveRequestChanged() {
                    if (root.activeRequest && root._isInput)
                        Qt.callLater(() => input.forceActiveFocus());
                }
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.backdrop
                opacity: root.activeRequest ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.animSmooth } }
                MouseArea { anchors.fill: parent; onClicked: {} }
            }

            Rectangle {
                id: dialog
                anchors.centerIn: parent
                width: Theme.dialogWidth
                implicitHeight: content.implicitHeight + Theme.dialogPadding * 2
                radius: Theme.dialogRadius
                color: Theme.glassBg()
                border.width: 1
                border.color: Theme.outlineVariant
                opacity: root.activeRequest ? 1 : 0
                scale: root.activeRequest ? 1 : 0.95

                Behavior on opacity { NumberAnimation { duration: Theme.animSmooth } }
                Behavior on scale { NumberAnimation { duration: Theme.animSmooth; easing.type: Easing.OutCubic } }

                ColumnLayout {
                    id: content
                    anchors.fill: parent
                    anchors.margins: Theme.dialogPadding
                    spacing: Theme.spacingMedium

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Theme.iconBluetooth
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.iconSizeLarge
                        color: Theme.accent
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Bluetooth Pairing"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLarge
                        font.bold: true
                        color: Theme.fg
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root._deviceLabel
                        color: Theme.fgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }

                    // Confirmation passkey display
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 6
                        visible: root._isConfirm && root.activeRequest && root.activeRequest.passkey > 0
                        text: String(root.activeRequest?.passkey ?? "").padStart(6, "0")
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeHero
                        font.bold: true
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root._isConfirm
                        text: root._kind === "serviceAuthorization"
                            ? `Authorize service ${root.activeRequest?.serviceUuid ?? ""}?`
                            : (root.activeRequest?.passkey > 0
                                ? "Confirm this passkey is shown on the device."
                                : "Allow this device to pair?")
                        color: Theme.fgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }

                    // Display-only PIN / passkey
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 6
                        visible: root._isDisplay
                        text: root._kind === "displayPinCode"
                            ? (root.activeRequest?.pinCode ?? "")
                            : String(root.activeRequest?.passkey ?? "").padStart(6, "0")
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeHero
                        font.bold: true
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root._isDisplay
                        text: "Enter this code on the device."
                        color: Theme.fgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        horizontalAlignment: Text.AlignHCenter
                    }

                    StyledTextField {
                        id: input
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        visible: root._isInput
                        field.inputMethodHints: root._kind === "passkey"
                            ? Qt.ImhDigitsOnly : Qt.ImhNone
                        field.maximumLength: root._kind === "passkey" ? 6 : 16
                        field.Keys.onReturnPressed: root._submit()
                        field.Keys.onEscapePressed: root._cancel()
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 8
                        spacing: Theme.spacingMedium
                        visible: !root._isDisplay

                        TextButton {
                            label: "Reject"
                            onClicked: root._cancel()
                        }
                        TextButton {
                            label: root._isInput ? "Submit" : "Approve"
                            onClicked: root._submit()
                        }
                    }

                    // Display variants only need a dismiss button.
                    TextButton {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 8
                        visible: root._isDisplay
                        label: "Dismiss"
                        onClicked: root.activeRequest = null
                    }
                }
            }

            Keys.onEscapePressed: root._cancel()
        }
    }

    function _submit() {
        const r = activeRequest;
        if (!r) return;
        if (r.kind === "pinCode") r.respondString(input.field.text);
        else if (r.kind === "passkey") r.respondUint(parseInt(input.field.text, 10) || 0);
        else if (_isConfirm) r.approve();
    }

    function _cancel() {
        if (activeRequest) activeRequest.reject();
    }
}
