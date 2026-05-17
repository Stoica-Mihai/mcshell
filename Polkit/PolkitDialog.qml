import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Polkit
import qs.Config
import qs.Widgets

// Polkit authentication agent — themed overlay dialog.
// Registers with D-Bus on creation. Shows when a privileged action
// needs authorization (pkexec, systemd, package managers, etc.).
//
// The scaffold (per-screen Variants, layer-shell overlay, backdrop, blur
// gating, opacity/scale animation, escape capture) lives in
// Widgets/ModalDialog.qml. The auth form is supplied via `contentComponent`
// and is instantiated per-screen; that's why the inner Connections and
// passwordInput ID live inside the Component rather than at root level.
Item {
    id: root

    PolkitAgent { id: agent }

    ShakeAnimation { id: shakeAnim }

    ModalDialog {
        id: modal
        active: agent.isActive
        namespace: Namespaces.polkit
        shakeOffsetX: shakeAnim.value
        onDismissed: if (agent.flow) agent.flow.cancelAuthenticationRequest()

        contentComponent: Component {
            ColumnLayout {
                id: form
                anchors.fill: parent
                anchors.margins: Theme.dialogPadding
                spacing: Theme.spacingLarge

                function _cancel() {
                    if (agent.flow) {
                        agent.flow.cancelAuthenticationRequest();
                        passwordInput.text = "";
                    }
                }

                function _submit() {
                    if (passwordInput.text !== "" && agent.flow) {
                        agent.flow.submit(passwordInput.text);
                        passwordInput.text = "";
                    }
                }

                Connections {
                    target: agent
                    function onAuthenticationRequestStarted() {
                        passwordInput.text = "";
                        passwordInput.forceActiveFocus();
                    }
                }

                Connections {
                    target: agent.flow
                    function onIsResponseRequiredChanged() {
                        if (agent.flow && agent.flow.isResponseRequired)
                            passwordInput.forceActiveFocus();
                    }
                    function onAuthenticationFailed() {
                        shakeAnim.shake();
                        passwordInput.forceActiveFocus();
                    }
                }

                // Lock icon
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Theme.iconLock
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.iconSizeLarge
                    color: Theme.accent
                }

                // Title
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Authentication Required"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLarge
                    font.bold: true
                    color: Theme.fg
                }

                // Action description
                Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    text: agent.flow?.message ?? ""
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.fgDim
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Item { Layout.preferredHeight: 4 }

                // Password input
                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    radius: Theme.radiusMedium
                    color: Theme.overlay
                    border.width: 1
                    border.color: passwordInput.activeFocus ? Theme.accent : Theme.border

                    Behavior on border.color { ColorAnimation { duration: Theme.animNormal } }

                    TextInput {
                        id: passwordInput
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingLarge
                        anchors.rightMargin: Theme.spacingLarge
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        color: Theme.fg
                        echoMode: (agent.flow?.responseVisible ?? false)
                            ? TextInput.Normal : TextInput.Password
                        clip: true
                        selectByMouse: true

                        onAccepted: form._submit()
                        Keys.onEscapePressed: form._cancel()

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: agent.flow?.inputPrompt || "Password"
                            color: Theme.fgDim
                            font: parent.font
                            visible: !parent.text && !parent.activeFocus
                        }
                    }
                }

                // Error / supplementary message
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: {
                        if (agent.flow?.failed)
                            return "Authentication failed — try again";
                        return agent.flow?.supplementaryMessage ?? "";
                    }
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: (agent.flow?.supplementaryIsError || agent.flow?.failed) ? Theme.red : Theme.fgDim
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }

                // Identity (show who's authenticating)
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Authenticating as " + (agent.flow?.selectedIdentity?.displayName ?? "")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeTiny
                    color: Theme.fgDim
                    opacity: Theme.opacitySubtle
                    visible: agent.flow?.selectedIdentity !== undefined
                }

                // Action buttons
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: Theme.spacingNormal

                    TextButton {
                        label: "Cancel"
                        onClicked: form._cancel()
                    }

                    TextButton {
                        label: "Authenticate"
                        baseColor: Theme.accent
                        hoverColor: Qt.darker(Theme.accent, 1.2)
                        textColor: Theme.bgSolid
                        bold: true
                        onClicked: form._submit()
                    }
                }
            }
        }
    }
}
