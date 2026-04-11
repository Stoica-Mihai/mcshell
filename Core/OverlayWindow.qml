import QtQuick
import Quickshell
import Quickshell.Wayland

// Shared base for mcshell's Wayland layer-shell overlays.
// Sets the usual transparent fullscreen-ready defaults; consumers still
// declare their own anchors (fullscreen vs partial) and can override any
// attached property.
PanelWindow {
    id: root

    property string namespace: "mcshell"
    property int layer: WlrLayer.Overlay
    property int focusMode: WlrKeyboardFocus.Exclusive

    color: "transparent"

    WlrLayershell.namespace: root.namespace
    WlrLayershell.layer: root.layer
    WlrLayershell.keyboardFocus: root.focusMode
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
}
