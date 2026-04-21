import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import qs.Config
import qs.Core
import qs.Widgets

// Polkit authentication agent — themed overlay dialog.
// Registers with D-Bus on creation. Shows when a privileged action
// needs authorization (pkexec, systemd, package managers, etc.).
Item {
    id: root

    PolkitAgent {
        id: agent
    }

    Variants {
        model: Quickshell.screens

        OverlayWindow {
            id: overlay
            namespace: Namespaces.polkit
            active: agent.isActive

            required property var modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
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

            // Backdrop
            Rectangle {
                anchors.fill: parent
                color: Theme.backdrop
                opacity: agent.isActive ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.animSmooth } }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {} // block clicks through backdrop
                }
            }

            // Dialog card
            Rectangle {
                id: dialog
                anchors.centerIn: parent
                width: Theme.dialogWidth
                implicitHeight: content.implicitHeight + Theme.dialogPadding * 2
                radius: Theme.dialogRadius
                color: Theme.bg
                border.width: 1
                border.color: Theme.border
                opacity: agent.isActive ? 1 : 0
                scale: agent.isActive ? 1 : 0.95

                Behavior on opacity { NumberAnimation { duration: Theme.animSmooth } }
                Behavior on scale { NumberAnimation { duration: Theme.animSmooth; easing.type: Easing.OutCubic } }

                // Shake on failed auth
                transform: Translate { x: shakeAnim.value }

                ShakeAnimation { id: shakeAnim }

                ColumnLayout {
                    id: content
                    anchors.fill: parent
                    anchors.margins: Theme.dialogPadding
                    spacing: Theme.spacingLarge

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

                            onAccepted: {
                                if (text !== "" && agent.flow) {
                                    agent.flow.submit(text);
                                    text = "";
                                }
                            }

                            Keys.onEscapePressed: {
                                if (agent.flow) {
                                    agent.flow.cancelAuthenticationRequest();
                                    text = "";
                                }
                            }

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
                            onClicked: {
                                if (agent.flow) {
                                    agent.flow.cancelAuthenticationRequest();
                                    passwordInput.text = "";
                                }
                            }
                        }

                        TextButton {
                            label: "Authenticate"
                            baseColor: Theme.accent
                            hoverColor: Qt.darker(Theme.accent, 1.2)
                            textColor: Theme.bgSolid
                            bold: true
                            onClicked: {
                                if (passwordInput.text !== "" && agent.flow) {
                                    agent.flow.submit(passwordInput.text);
                                    passwordInput.text = "";
                                }
                            }
                        }
                    }
                }
            }

            // Keyboard handler
            Item {
                focus: agent.isActive
                Keys.onEscapePressed: {
                    if (agent.flow) {
                        agent.flow.cancelAuthenticationRequest();
                        passwordInput.text = "";
                    }
                }
            }
        }
    }
}
