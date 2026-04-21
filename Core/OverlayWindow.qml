import QtQuick
import Quickshell
import Quickshell.Wayland

// Shared base for mcshell's Wayland layer-shell overlays.
//
// The window is permanently visible — destroying the QQuickWindow on hide
// races with Qt 6.11 Wayland handleScreensChanged (segfaults in
// calculateScreenFromSurfaceEvents). Consumers gate input by binding
// `active` to their open state: when false the surface is click-through
// (empty mask) and releases keyboard focus; when true the mask clears and
// `focusMode` is applied.
//
// Consumers still declare their own anchors (fullscreen vs partial) and
// may override any attached property.
PanelWindow {
    id: root

    property string namespace: "mcshell"
    // Default Top so normal user overlays (launcher, keybinds, window
    // switcher, polkit, notifications) stack below truly topmost surfaces
    // like the screenshot tool — which upgrades to Overlay explicitly.
    property int layer: WlrLayer.Top
    property int focusMode: WlrKeyboardFocus.Exclusive
    property bool active: true

    visible: true
    color: "transparent"
    mask: active ? null : _emptyRegion

    Region { id: _emptyRegion }

    WlrLayershell.namespace: root.namespace
    WlrLayershell.layer: root.layer
    WlrLayershell.keyboardFocus: active ? root.focusMode : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
}
