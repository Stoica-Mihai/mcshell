import QtQuick
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
    clip: true
    opacity: isVisible ? 1.0 : 0.0

    Behavior on width { NumberAnimation { duration: Theme.animCarousel; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: Theme.animSmooth } }

    // Card content goes here
    default property alias contentData: cardContent.data

    // Card background
    property bool focused: launcher ? launcher.editMode : false
    property color borderColor: focused && isCurrent ? Theme.accent : Theme.border
    property bool showBorder: isCurrent

    Rectangle {
        id: card
        anchors.fill: parent
        radius: strip.isCurrent ? 14 : 8
        color: Theme.bg
        clip: true

        Behavior on radius { NumberAnimation { duration: Theme.animCarousel; easing.type: Easing.OutCubic } }

        // Fallback click for expanded card (below content so Flickable takes priority)
        MouseArea {
            anchors.fill: parent
            visible: strip.isCurrent
            cursorShape: Qt.PointingHandCursor
            onClicked: strip.onStripActivated()
        }

        Item {
            id: cardContent
            anchors.fill: parent
            property bool isCurrent: strip.isCurrent
            property real cardPadding: 14
        }

        // Border overlay — on top of content so full-bleed images don't cover it
        Rectangle {
            anchors.fill: parent
            radius: card.radius
            color: "transparent"
            border.width: strip.showBorder ? (strip.focused ? 2 : 1) : 0
            border.color: strip.borderColor
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
