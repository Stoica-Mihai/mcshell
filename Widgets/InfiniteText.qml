import QtQuick
import qs.Config

// Text that scrolls infinitely on hover when content overflows.
// Two copies of the text slide left in a loop with a gap between them.
// Same API as HoverText (normalColor, hoverColor, clicked signal).
Item {
    id: root

    property string text: ""
    property alias font: label.font
    property color normalColor: Theme.fg
    property color hoverColor: Theme.accent
    readonly property alias hovered: mouse.containsMouse

    signal clicked()

    readonly property real _gap: 40
    readonly property real _cycleWidth: label.implicitWidth + _gap

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight
    clip: true

    readonly property bool _overflows: label.implicitWidth > root.width
    readonly property bool _scrolling: mouse.containsMouse && _overflows
    readonly property color _color: mouse.containsMouse ? hoverColor : normalColor

    // Primary text
    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        font.family: Theme.fontFamily
        color: root._color
        text: root.text
        elide: !root._scrolling ? Text.ElideRight : Text.ElideNone
        width: !root._scrolling ? root.width : implicitWidth
        x: root._scrolling ? slider.offset : 0

        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    // Duplicate for seamless loop
    Text {
        anchors.verticalCenter: parent.verticalCenter
        font.family: Theme.fontFamily
        color: root._color
        text: root.text
        visible: root._scrolling
        x: slider.offset + root._cycleWidth

        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    // Shared scroll driver — both texts offset from this
    QtObject {
        id: slider
        property real offset: 0
    }

    NumberAnimation {
        id: scrollAnim
        target: slider
        property: "offset"
        from: 0
        to: -root._cycleWidth
        duration: root._cycleWidth * 20
        loops: Animation.Infinite
        easing.type: Easing.Linear
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onContainsMouseChanged: {
            if (containsMouse && root._overflows) {
                scrollAnim.start();
            } else {
                scrollAnim.stop();
                slider.offset = 0;
            }
        }
    }
}
