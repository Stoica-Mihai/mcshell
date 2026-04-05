import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.Config

// PopupWindow with slide-down/up animation and skewed parallelogram background.
// Set `fullHeight` to the content height. Call `open()` / `close()`.
// After opening, `fullHeight` can be bound reactively — the popup auto-resizes.
//
// Set `skewType` to match the bar segment this popup drops from:
//   "center" — both edges lean left (clock/calendar)
//   "right"  — left edge leans right, right edge straight (volume, media, notifications)
//   "none"   — plain rectangle (no skew)
//
// Children are placed inside the background automatically.
PopupWindow {
    id: root

    property real fullHeight: 100
    property real openFraction: 0
    property bool isOpen: false
    property bool animating: openAnim.running || closeAnim.running
    property string skewType: "none"

    default property alias contentData: bgContent.data

    visible: false
    color: "transparent"
    implicitHeight: animating ? Math.max(1, fullHeight * openFraction) : (isOpen ? Math.max(1, fullHeight) : 1)

    property bool autoPosition: true

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

    // ── Skew geometry ─────────────────────────────────────
    // Bar's diagonal slant defines the starting offset.
    // The dropdown's top edge matches the bar's bottom edge,
    // then the lean continues moderately for the body.
    readonly property real _barSlant: Theme.barDiagSlant
    readonly property real _lean: Theme.popupSkew

    // Vertex coordinates per skewType
    //   "right":  top-left starts at barSlant (bar's bottom-left), lean continues
    //   "center": both edges offset by lean
    //   "none":   rectangle
    readonly property real _tlX: skewType === "right"  ? _barSlant
                                : skewType === "center" ? _lean : 0
    readonly property real _trX: width
    readonly property real _brX: skewType === "center" ? width - _lean : width
    readonly property real _blX: skewType === "right"  ? _barSlant + _lean
                                : skewType === "center" ? 0 : 0

    // ── Themed background ─────────────────────────────────
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: Theme.surfaceContainer
            strokeColor: Theme.outlineVariant
            strokeWidth: 1

            startX: root._tlX; startY: 0
            PathLine { x: root._trX; y: 0 }
            PathLine { x: root._brX; y: root.height }
            PathLine { x: root._blX; y: root.height }
            PathLine { x: root._tlX; y: 0 }
        }
    }

    Item {
        id: bgContent
        anchors.fill: parent
        anchors.leftMargin: Math.max(root._tlX, root._blX)
        anchors.rightMargin: root.width - Math.min(root._trX, root._brX)
    }

    // Escape to close
    Item {
        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: root.close()
    }
}
