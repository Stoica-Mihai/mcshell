import QtQuick
import Quickshell
import qs.Config

// PopupWindow with slide-down/up animation and themed background.
// Set `fullHeight` to the content height. Call `open()` / `close()`.
// After opening, `fullHeight` can be bound reactively — the popup auto-resizes.
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
    implicitHeight: animating ? Math.max(1, fullHeight * openFraction) : (isOpen ? Math.max(1, _smoothHeight) : 1)

    // Smooth height transitions when content resizes while open
    property real _smoothHeight: fullHeight
    Behavior on _smoothHeight {
        enabled: root.isOpen && !root.animating
        NumberAnimation { duration: Theme.animSmooth; easing.type: Easing.OutCubic }
    }

    property bool autoPosition: true

    // ── Panel state (shared dropdown API) ─────────────────
    property string activePanel: ""
    property Item anchorSection: null
    property real anchorX: 0

    function togglePanel(name) {
        if (activePanel === name) closePanel();
        else openPanel(name);
    }

    function openPanel(name) {
        close();
        activePanel = name;
        if (anchorSection) {
            anchor.item = anchorSection;
            anchor.rect.x = anchorX;
            anchor.rect.y = anchorSection.height;
        }
        // Defer open by one frame so content layout settles and
        // fullHeight reads the real implicitHeight, not a stale 0.
        Qt.callLater(open);
    }

    function closePanel() {
        close();
    }

    // ── Raw open/close (used by panel API and standalone popups) ──
    function open() {
        if (anchor.item && autoPosition)
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
        radius: 0
        color: Theme.surfaceContainer
        border.width: 1
        border.color: Theme.outlineVariant

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
