import QtQuick
import qs.Config
import qs.Widgets

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

    Behavior on width {
        enabled: launcher && launcher.isOpen && !launcher._suppressCarouselAnim
        NumberAnimation { duration: Theme.animCarousel; easing.type: Easing.OutCubic }
    }
    Behavior on opacity {
        enabled: launcher && launcher.isOpen && !launcher._suppressCarouselAnim
        NumberAnimation { duration: Theme.animSmooth }
    }

    // Card content goes here
    default property alias contentData: card.contentData

    // Card background
    property bool focused: launcher ? launcher.editMode : false
    property color borderColor: focused && isCurrent ? Theme.accent : Theme.outlineVariant
    property bool showBorder: isCurrent

    ParallelogramCard {
        id: card
        anchors.fill: parent
        showBorder: strip.showBorder && !animBorder.active && animBorder._progress === 0
        borderColor: strip.borderColor
        borderWidth: strip.showBorder ? (strip.focused ? 2 : 1) : 0
        skewContent: true
        isCurrent: strip.isCurrent
    }

    AnimatedBorder {
        id: animBorder
        anchors.fill: parent
        active: strip.isCurrent && strip.focused
        style: UserSettings.borderAnimation
        color: Theme.accent
        thickness: 2
    }

    // Fallback click for expanded card
    MouseArea {
        anchors.fill: parent
        visible: strip.isCurrent
        cursorShape: Qt.PointingHandCursor
        onClicked: strip.onStripActivated()
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
