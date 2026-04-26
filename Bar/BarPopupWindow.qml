import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Core

// Reusable layer shell window for bar dropdowns that need isolation from
// the main bar surface (so they can receive keyboard focus).
//
// Visually matches the original AnimatedPopup design used by the calendar:
// - Themed background (surfaceContainer fill + outlineVariant border)
// - Slide-down animation via animated height
// - Width matches the bar's center parallelogram (minus slant)
// - Positioned tight below the bar
//
// Usage:
//   BarPopupWindow {
//       cardWidth: centerSection.width - Theme.barDiagSlant
//       cardHeight: someContent.fullHeight
//       wantsKeyboardFocus: true  // for panels with text input
//       SomeContent { id: someContent; anchors.fill: parent }
//   }
OverlayWindow {
    id: root
    namespace: Namespaces.barPopup
    active: isOpen
    focusMode: wantsKeyboardFocus ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property bool isOpen: false
    property real cardWidth: 320
    property real cardHeight: 200
    property bool wantsKeyboardFocus: false
    // Horizontal placement under the bar: "left", "center" (default), "right".
    // Pick the one that lines up with the bar segment that owns the trigger.
    property string cardAlignment: "center"

    property real _openFraction: 0
    property bool _animating: openAnim.running || closeAnim.running

    default property alias contentData: cardContent.data

    // Fires before isOpen flips to true on open() — gives subclasses a hook
    // to reassign `screen` (or other surface-lifetime state) before the
    // Wayland surface activates, so attached effects like BackgroundEffect
    // bind to the correct surface.
    signal aboutToOpen()

    function open() {
        aboutToOpen();
        isOpen = true;
        closeAnim.stop();
        openAnim.start();
    }
    function close() {
        if (!isOpen) return;
        isOpen = false;
        openAnim.stop();
        closeAnim.start();
    }
    function toggle() {
        if (isOpen) close();
        else open();
    }

    NumberAnimation {
        id: openAnim
        target: root
        property: "_openFraction"
        from: 0; to: 1
        duration: Theme.animSmooth
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: closeAnim
        target: root
        property: "_openFraction"
        from: root._openFraction; to: 0
        duration: Theme.animSmooth
        easing.type: Easing.InCubic
    }

    anchors { top: true; bottom: true; left: true; right: true }

    // Background blur — only the visible card rectangle.
    BackgroundEffect.blurRegion: UserSettings.blurEnabled ? cardBlurRegion : null
    Region { id: cardBlurRegion; item: card }

    // FocusScope so child inputs can take active focus via forceActiveFocus()
    // without being blocked, and Escape falls through to here if not handled.
    // Requires `wantsKeyboardFocus: true` for Escape to arrive — the
    // compositor doesn't route keys to surfaces with keyboardFocus: None.
    FocusScope {
        anchors.fill: parent
        focus: root.isOpen
        Keys.onEscapePressed: root.close()

        // ── Backdrop — invisible click catcher for outside-to-dismiss ──
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        // ── Card — tight below the bar, matching bar width ──
        // topMargin = barMargin (top of bar) + barHeight (bar content)
        // No bottom barMargin so the card touches the bar edge directly.
        Rectangle {
            id: card
            anchors.top: parent.top
            anchors.topMargin: Theme.barMargin + Theme.barHeight
            anchors.horizontalCenter: root.cardAlignment === "center" ? parent.horizontalCenter : undefined
            anchors.left: root.cardAlignment === "left" ? parent.left : undefined
            anchors.right: root.cardAlignment === "right" ? parent.right : undefined
            anchors.leftMargin: root.cardAlignment === "left" ? Theme.barMargin + 1 : 0
            anchors.rightMargin: root.cardAlignment === "right" ? Theme.barMargin + 1 : 0
            width: root.cardWidth
            // Animated height — slide-down from 0 to cardHeight
            height: root._animating
                ? Math.max(1, root.cardHeight * root._openFraction)
                : (root.isOpen ? root.cardHeight : 1)
            clip: true
            color: Theme.glassSurface()
            border.width: 1
            border.color: Theme.outlineVariant
            radius: 0  // matches original AnimatedPopup (no rounded corners)

            // Block backdrop clicks on the card itself
            MouseArea { anchors.fill: parent }

            Item {
                id: cardContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: root.cardHeight  // full height — card clips during animation
            }
        }
    }
}
