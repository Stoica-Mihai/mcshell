import QtQuick
import qs.Config

// Horizontal shake animation for auth-failure feedback.
// Attach via `transform: Translate { x: shakeAnim.value }` and trigger with
// `shakeAnim.shake()`. Canonical amplitude curve: -12, 12, -8, 8, -4, 0.
SequentialAnimation {
    id: root

    property real value: 0

    function shake() { restart(); }

    NumberAnimation { target: root; property: "value"; to: -12; duration: Theme.animLockShake; easing.type: Easing.OutCubic }
    NumberAnimation { target: root; property: "value"; to:  12; duration: Theme.animLockShake; easing.type: Easing.OutCubic }
    NumberAnimation { target: root; property: "value"; to:  -8; duration: Theme.animLockShake; easing.type: Easing.OutCubic }
    NumberAnimation { target: root; property: "value"; to:   8; duration: Theme.animLockShake; easing.type: Easing.OutCubic }
    NumberAnimation { target: root; property: "value"; to:  -4; duration: Theme.animLockShake; easing.type: Easing.OutCubic }
    NumberAnimation { target: root; property: "value"; to:   0; duration: Theme.animLockShake; easing.type: Easing.OutCubic }
}
