import QtQuick
import QtQuick.Shapes
import qs.Config

// Reusable carousel strip item for the app launcher.
// Handles sizing, visibility, animations, selection, and card background.
// Place content inside via default property.
Item {
    id: strip

    required property var modelData
    required property int index

    // Launcher reference — auto-binds carousel properties
    property var launcher: null
    property int selectedIndex: launcher ? launcher.selectedIndex : 0
    property int sideCount: launcher ? launcher.sideCount : 5
    property real expandedWidth: launcher ? launcher.expandedWidth : 500
    property real stripWidth: launcher ? launcher.stripWidth : 80
    property real carouselHeight: launcher ? launcher.carouselHeight : 350

    readonly property bool isCurrent: index === selectedIndex
    readonly property bool isVisible: Math.abs(index - selectedIndex) <= sideCount

    width: isVisible ? (isCurrent ? expandedWidth : stripWidth) : 0
    height: carouselHeight
    opacity: isVisible ? 1.0 : 0.0

    Behavior on width { NumberAnimation { duration: Theme.animCarousel; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: Theme.animSmooth } }

    // Card content goes here
    default property alias contentData: cardContent.data

    // Card background
    property bool focused: launcher ? launcher.editMode : false
    property color borderColor: focused && isCurrent ? Theme.accent : Theme.border
    property bool showBorder: isCurrent

    // Skew: horizontal offset at top/bottom from center
    readonly property real _skew: -0.03
    readonly property real _skewPx: _skew * height / 2

    // Parallelogram corners (top leans right)
    readonly property real _tl: -_skewPx
    readonly property real _tr: width - _skewPx
    readonly property real _bl: _skewPx
    readonly property real _br: width + _skewPx

    // Border width
    readonly property real _bw: showBorder ? (focused ? 2 : 1) : 0

    // Background fill — behind content
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: Theme.bg
            strokeColor: "transparent"
            strokeWidth: 0

            startX: strip._tl; startY: 0
            PathLine { x: strip._tr; y: 0 }
            PathLine { x: strip._br; y: strip.height }
            PathLine { x: strip._bl; y: strip.height }
            PathLine { x: strip._tl; y: 0 }
        }
    }

    // Fallback click for expanded card
    MouseArea {
        anchors.fill: parent
        visible: strip.isCurrent
        cursorShape: Qt.PointingHandCursor
        onClicked: strip.onStripActivated()
    }

    // Content wrapper — 1px padding creates transparent edge in the layer texture,
    // so bilinear filtering smooths the diagonal edges after transform
    Item {
        id: contentWrapper
        anchors.fill: parent
        anchors.margins: -1

        layer.enabled: true
        layer.smooth: true

        transform: Matrix4x4 {
            matrix: Qt.matrix4x4(
                1, strip._skew, 0, -strip._skew * contentWrapper.height / 2,
                0, 1,           0, 0,
                0, 0,           1, 0,
                0, 0,           0, 1
            )
        }

        Item {
            id: cardContent
            anchors.fill: parent
            anchors.margins: 1
            property bool isCurrent: strip.isCurrent
            property real cardPadding: 14
        }
    }

    // Border — on top of content, only for current card
    Shape {
        anchors.fill: parent
        visible: strip.showBorder
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: strip.borderColor
            strokeWidth: strip._bw
            joinStyle: ShapePath.MiterJoin

            startX: strip._tl; startY: 0
            PathLine { x: strip._tr; y: 0 }
            PathLine { x: strip._br; y: strip.height }
            PathLine { x: strip._bl; y: strip.height }
            PathLine { x: strip._tl; y: 0 }
        }
    }

    // Click to select or activate — override these for custom behavior
    function onStripSelected() { if (launcher) launcher.selectedIndex = index; }
    function onStripActivated() { if (launcher) launcher.activate(); }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        // Only intercept clicks on collapsed cards. When expanded,
        // let content (Flickable, buttons, etc.) handle events.
        enabled: !strip.isCurrent
        onClicked: strip.onStripSelected()
    }
}
