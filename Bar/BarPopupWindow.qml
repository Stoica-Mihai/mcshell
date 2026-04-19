import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config

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
PanelWindow {
    id: root

    property bool isOpen: false
    property var screen: null
    property real cardWidth: 320
    property real cardHeight: 200
    property bool wantsKeyboardFocus: false
    property string layershellNamespace: "mcshell-bar-popup"

    property real _openFraction: 0
    property bool _animating: openAnim.running || closeAnim.running

    default property alias contentData: cardContent.data

    function open() {
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

    // ── Window setup ────────────────────────────────────
    // Always-visible layer-shell surface — see AppLauncher for why.
    visible: true
    mask: isOpen ? null : _emptyRegion
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }

    Region { id: _emptyRegion }

    WlrLayershell.namespace: root.layershellNamespace
    // Top layer so ScreenshotOverlay (on Overlay) sits above and receives
    // input first. Other user overlays are also Top and stacked as siblings
    // by map order.
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: (isOpen && wantsKeyboardFocus)
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    // FocusScope so child inputs can take active focus via forceActiveFocus()
    // without being blocked, and Escape falls through to here if not handled.
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
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.cardWidth
            // Animated height — slide-down from 0 to cardHeight
            height: root._animating
                ? Math.max(1, root.cardHeight * root._openFraction)
                : (root.isOpen ? root.cardHeight : 1)
            clip: true
            color: Theme.surfaceContainer
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
