import QtQuick
import qs.Config

// Reusable carousel strip item for the app launcher.
// Handles sizing, visibility, animations, selection, and card background.
// Place content inside via default property.
Item {
    id: strip

    required property var modelData
    required property int index

    // Launcher references — set these from the parent
    property int selectedIndex: 0
    property int sideCount: 5
    property real expandedWidth: 500
    property real stripWidth: 80
    property real carouselHeight: 350

    readonly property bool isCurrent: index === selectedIndex
    readonly property bool isVisible: Math.abs(index - selectedIndex) <= sideCount

    width: isVisible ? (isCurrent ? expandedWidth : stripWidth) : 0
    height: carouselHeight
    clip: true
    opacity: isVisible ? 1.0 : 0.0

    Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 200 } }

    // Card content goes here
    default property alias contentData: cardContent.data

    // Card background
    property color borderColor: Theme.border
    property bool showBorder: isCurrent

    Rectangle {
        id: card
        anchors.fill: parent
        radius: strip.isCurrent ? 14 : 8
        color: Theme.bg
        clip: true
        border.width: strip.showBorder ? 1 : 0
        border.color: strip.borderColor

        Behavior on radius { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

        Item {
            id: cardContent
            anchors.fill: parent
        }
    }

    // Click to select or activate
    signal activated()
    signal selected()

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (strip.isCurrent)
                strip.activated();
            else
                strip.selected();
        }
    }
}
