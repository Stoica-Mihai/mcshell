import QtQuick
import qs.Config

// Standard smooth transition: animSmooth duration, OutCubic easing.
// Use inside a Behavior: `Behavior on x { SmoothAnim {} }`.
NumberAnimation {
    duration: Theme.animSmooth
    easing.type: Easing.OutCubic
}
