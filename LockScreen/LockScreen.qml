import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.Config
import qs.Widgets

// Lock screen module using the Wayland ext_session_lock_v1 protocol.
//
// Usage from shell.qml:
//   import qs.LockScreen
//   ShellRoot { LockScreen { id: lockScreen } }
//
// Then call lockScreen.lock() from a power menu button or IPC handler.
Item {
    id: root

    // ── Public API ──────────────────────────────────────
    readonly property bool isLocked: lockSession.locked

    function lock() {
        gracePeriodActive = (Date.now() - lastUnlockTime) < gracePeriodMs;
        lockSession.locked = true;
        pam.start();
    }

    // ── Private state ───────────────────────────────────
    property real lastUnlockTime: 0
    readonly property int gracePeriodMs: 5000
    property bool gracePeriodActive: false
    property string currentPassword: ""
    property bool authInProgress: false
    property string statusMessage: ""
    property bool statusIsError: false
    property bool waitingForResponse: false

    // ── PAM authentication ──────────────────────────────
    PamContext {
        id: pam
        config: "login"

        onPamMessage: {
            if (pam.responseRequired) {
                if (root.currentPassword !== "") {
                    pam.respond(root.currentPassword);
                    root.authInProgress = true;
                } else {
                    root.waitingForResponse = true;
                    // Don't use pam.message here — it's "Password:" which is redundant
                    root.statusMessage = "";
                    root.statusIsError = false;
                }
            } else if (pam.messageIsError) {
                // Only show actual error messages, not generic prompts
                const msg = pam.message || "";
                if (msg.toLowerCase().indexOf("password") < 0)
                    root.statusMessage = msg;
                root.statusIsError = true;
            }
        }

        onCompleted: result => {
            root.authInProgress = false;
            if (result === PamResult.Success) {
                root.lastUnlockTime = Date.now();
                root.currentPassword = "";
                root.statusMessage = "";
                root.waitingForResponse = false;
                lockSession.locked = false;
            } else {
                root.currentPassword = "";
                root.statusMessage = "Authentication failed";
                root.statusIsError = true;
                root.waitingForResponse = false;
                shakeAnim.shake();
                pam.start();
            }
        }

        onError: {
            // Error fires before completed(PamResult.Error) — just capture the message.
            // The restart happens in onCompleted to avoid double-starting PAM.
            const msg = pam.message || "";
            root.statusMessage = (msg.toLowerCase().indexOf("password") >= 0) ? "Authentication error" : (msg || "Authentication error");
            root.statusIsError = true;
        }
    }

    function tryUnlock() {
        if (gracePeriodActive) {
            lastUnlockTime = Date.now();
            currentPassword = "";
            statusMessage = "";
            waitingForResponse = false;
            lockSession.locked = false;
            return;
        }

        if (waitingForResponse) {
            pam.respond(currentPassword);
            authInProgress = true;
            waitingForResponse = false;
            return;
        }

        pam.abort();
        pam.start();
    }

    // ── Session lock ────────────────────────────────────
    WlSessionLock {
        id: lockSession

        WlSessionLockSurface {
            id: lockSurface
            color: Theme.bgSolid

            // Root container filling the entire lock surface
            Rectangle {
                anchors.fill: parent
                color: Theme.bgSolid

                // Mouse area to reclaim focus on cursor movement
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onEntered: {
                        if (hiddenInput && !hiddenInput.activeFocus) {
                            hiddenInput.forceActiveFocus();
                        }
                    }
                }

                // Hidden text input that captures all keystrokes
                TextInput {
                    id: hiddenInput
                    width: 0
                    height: 0
                    visible: false
                    enabled: !root.authInProgress
                    echoMode: TextInput.Password
                    passwordMaskDelay: 0

                    onTextChanged: {
                        if (root.currentPassword !== text)
                            root.currentPassword = text;
                    }

                    Connections {
                        target: root
                        function onCurrentPasswordChanged() {
                            if (hiddenInput.text !== root.currentPassword)
                                hiddenInput.text = root.currentPassword;
                        }
                    }

                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.tryUnlock();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            root.currentPassword = "";
                            event.accepted = true;
                        }
                    }

                    Component.onCompleted: forceActiveFocus()
                }

                // ── Center content ──────────────────────────
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Theme.spacingNormal

                    // Lock icon
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.iconSizeLarge
                        color: Theme.accent
                        text: Theme.iconLock
                        visible: lockSession.secure
                    }

                    // Securing indicator (before compositor confirms)
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.yellow
                        text: "Securing..."
                        visible: !lockSession.secure
                        opacity: visible ? 1.0 : 0.0

                        SequentialAnimation on opacity {
                            running: !lockSession.secure
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.4; duration: Theme.animLockFade; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1.0; duration: Theme.animLockFade; easing.type: Easing.InOutQuad }
                        }
                    }

                    // Large clock
                    Text {
                        id: clockText
                        Layout.alignment: Qt.AlignHCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeDisplay
                        font.weight: Font.Bold
                        color: Theme.fg
                        text: Qt.formatTime(clockTimer.currentTime, "HH:mm")

                        Timer {
                            id: clockTimer
                            property date currentTime: new Date()
                            interval: 1000
                            running: lockSession.locked
                            repeat: true
                            triggeredOnStart: true
                            onTriggered: currentTime = new Date()
                        }
                    }

                    // Date
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.fgDim
                        text: Qt.formatDate(clockTimer.currentTime, "dddd, MMMM d")
                    }

                    // Spacer
                    Item { Layout.preferredHeight: 32 }

                    // Grace period hint
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.green
                        text: "Press Enter to unlock"
                        visible: root.gracePeriodActive && lockSession.secure
                        opacity: visible ? 1.0 : 0.0

                        Behavior on opacity {
                            NumberAnimation { duration: Theme.animSmooth; easing.type: Easing.OutCubic }
                        }
                    }

                    // ── Password dots ───────────────────────
                    Item {
                        id: passwordArea
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Math.max(200, dotRow.implicitWidth + 48)
                        Layout.preferredHeight: 48
                        visible: lockSession.secure && !root.gracePeriodActive

                        // Shake animation on auth failure
                        transform: Translate { x: shakeAnim.value }

                        ShakeAnimation { id: shakeAnim }

                        Rectangle {
                            anchors.fill: parent
                            radius: 24
                            color: Theme.bgHover
                            border.width: 1
                            border.color: root.statusIsError ? Theme.red : (root.currentPassword.length > 0 ? Theme.accent : Theme.border)

                            Behavior on border.color {
                                ColorAnimation { duration: Theme.animNormal }
                            }
                        }

                        Row {
                            id: dotRow
                            anchors.centerIn: parent
                            spacing: Theme.spacingNormal

                            Repeater {
                                model: root.currentPassword.length

                                Rectangle {
                                    required property int index
                                    width: 10
                                    height: 10
                                    radius: 5
                                    color: Theme.fg

                                    // Pop-in animation for each new dot
                                    scale: 0
                                    Component.onCompleted: scale = 1

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: Theme.animPopIn
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }
                        }

                        // Blinking cursor when empty
                        Rectangle {
                            anchors.centerIn: parent
                            width: 2
                            height: 20
                            radius: 1
                            color: Theme.fgDim
                            visible: root.currentPassword.length === 0 && !root.authInProgress

                            SequentialAnimation on opacity {
                                running: root.currentPassword.length === 0 && !root.authInProgress
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.0; duration: Theme.animCursorBlink; easing.type: Easing.InOutQuad }
                                NumberAnimation { to: 1.0; duration: Theme.animCursorBlink; easing.type: Easing.InOutQuad }
                            }
                        }
                    }

                    // ── Status text ─────────────────────────
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        color: root.statusIsError ? Theme.red : Theme.fgDim
                        text: root.authInProgress ? "Authenticating..."
                            : root.statusMessage !== "" ? root.statusMessage
                            : ""
                        visible: lockSession.secure && !root.gracePeriodActive

                        Behavior on color {
                            ColorAnimation { duration: Theme.animNormal }
                        }
                    }
                }
            }
        }
    }
}
