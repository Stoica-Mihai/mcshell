import QtQuick
import Quickshell

// PopupWindow with slide-down/up animation.
// Set `fullHeight` to the content height. Call `open()` / `close()`.
PopupWindow {
    id: root

    property real fullHeight: 100
    property real openFraction: 0
    property bool isOpen: false

    visible: false
    color: "transparent"
    implicitHeight: Math.max(1, fullHeight * openFraction)

    function open() {
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
        duration: 250
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: closeAnim
        target: root
        property: "openFraction"
        from: root.openFraction; to: 0
        duration: 200
        easing.type: Easing.InCubic
        onFinished: root.visible = false
    }

    // Escape to close
    Item {
        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: root.close()
    }
}
