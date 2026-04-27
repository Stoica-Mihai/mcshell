import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Core

// Layer-shell overlay hosting the keybind hints panel.
//
// Replaces the original AnimatedPopup-based dropdown. An xdg-popup with
// grabFocus would either lose keyboard input (Qt::ToolTip → search field
// unfocusable) or take a Wayland xdg-popup grab — which fights the bar's
// other dropdowns over xdg-popup nesting and leaves the toggle keybind
// in an inconsistent state once the grab is established. Layer-shell
// owns its own keyboardFocus without participating in xdg-popup at all.
Item {
    id: root

    property bool isOpen: false

    function open()  { if (!isOpen) isOpen = true; }
    function close() { if (isOpen)  isOpen = false; }
    function toggle() { isOpen = !isOpen; }

    readonly property real fullHeight: 460
    readonly property real overlayWidth: Theme.barSideWidth - Theme.barDiagSlant

    // Slide animation state — shared across all per-screen overlays so the
    // visible one gets the same height curve the old AnimatedPopup had.
    property real openFraction: 0
    readonly property bool _animating: openAnim.running || closeAnim.running

    NumberAnimation {
        id: openAnim
        target: root; property: "openFraction"
        from: 0; to: 1
        duration: Theme.animSmooth; easing.type: Easing.OutCubic
    }
    NumberAnimation {
        id: closeAnim
        target: root; property: "openFraction"
        from: root.openFraction; to: 0
        duration: Theme.animSmooth; easing.type: Easing.InCubic
    }

    onIsOpenChanged: {
        if (isOpen) { closeAnim.stop(); openAnim.start(); }
        else        { openAnim.stop();  closeAnim.start(); }
    }

    // Per-screen layer surface. Only the focused-screen instance renders
    // content; the rest stay at 1px transparent (OverlayWindow keeps the
    // QQuickWindow alive permanently to avoid Qt 6.11 screen-swap races).
    Variants {
        model: Quickshell.screens

        delegate: OverlayWindow {
            id: overlay
            required property var modelData
            screen: modelData

            namespace: Namespaces.keybinds

            readonly property bool _isFocused:
                FocusedOutput.name === "" || FocusedOutput.name === modelData.name
            readonly property bool _wantsContent: (root.isOpen || root._animating) && _isFocused

            // Hold focus while open or animating so the search field can
            // receive keyboard input without xdg-popup grab.
            active: _wantsContent
            focusMode: WlrKeyboardFocus.Exclusive

            anchors { top: true; left: true }
            margins {
                // Align with the bar's left section (barRect.x) and tuck
                // up under its content edge so the overlay reads as a
                // direct extension of the bar — same offsets the old
                // anchored popup ended up at.
                left: Theme.barMargin + 1
                top: Theme.barMargin + Theme.barHeight
            }

            implicitWidth: root.overlayWidth
            implicitHeight: _wantsContent
                ? Math.max(1, root._animating
                    ? root.fullHeight * root.openFraction
                    : root.fullHeight)
                : 1

            BackgroundEffect.blurRegion: UserSettings.blurEnabled && _wantsContent
                ? bgRegion : null
            Region { id: bgRegion; item: bg }

            Rectangle {
                id: bg
                anchors.fill: parent
                visible: overlay._wantsContent
                color: Theme.glassSurface()
                border.width: 1
                border.color: Theme.outlineVariant

                KeybindPanel {
                    id: panel
                    anchors.fill: parent
                    visible: bg.visible
                    enabled: visible
                    windowOpen: root.isOpen && overlay._isFocused
                }
            }

            Shortcut {
                sequence: "Escape"
                enabled: overlay._wantsContent
                onActivated: root.close()
            }
        }
    }
}
