import QtQuick
import Quickshell
import qs.Config

// PopupWindow with slide-down/up animation and themed background.
// Set `fullHeight` to the content height. Call `open()` / `close()`.
// After opening, `fullHeight` can be bound reactively — the popup auto-resizes.
//
// Set `connected: true` (default) for bar-attached dropdowns (flat top, rounded bottom).
// Set `connected: false` for floating popups (all corners rounded).
//
// Children are placed inside the themed background automatically.
PopupWindow {
    id: root

    property real fullHeight: 100
    property real openFraction: 0
    property bool isOpen: false
    property bool animating: openAnim.running || closeAnim.running

    default property alias contentData: bgContent.data

    visible: false
    color: "transparent"
    implicitHeight: animating ? Math.max(1, fullHeight * openFraction) : (isOpen ? Math.max(1, fullHeight) : 1)

    function open() {
        if (anchor.item)
            anchor.rect.y = (Theme.barHeight + anchor.item.height) / 2 - 3;
        visible = true;
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

    NumberAnimation {
        id: openAnim
        target: root
        property: "openFraction"
        from: 0; to: 1
        duration: Theme.animSmooth
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: closeAnim
        target: root
        property: "openFraction"
        from: root.openFraction; to: 0
        duration: Theme.animSmooth
        easing.type: Easing.InCubic
        onFinished: root.visible = false
    }

    // ── Themed background ─────────────────────────────────
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Theme.barRadius
        color: Theme.bg
        border.width: 1
        border.color: Theme.border
        clip: true

        Item {
            id: bgContent
            anchors.fill: parent
        }
    }

    // Escape to close
    Item {
        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: root.close()
    }
}
