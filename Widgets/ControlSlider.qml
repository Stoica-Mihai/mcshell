import QtQuick
import QtQuick.Layouts
import qs.Config

// Reusable labeled slider: icon + label + percentage + SliderTrack.
// Used by VolumeSlider, BrightnessSlider, AppVolume.
Item {
    id: root

    property string icon: ""
    property string label: ""
    property real value: 0            // 0.0 to 1.0
    property color accentColor: Theme.accent
    property bool muted: false
    property int iconSize: 16
    property int trackHeight: 6
    property int knobSize: 14

    // Expose for parents that need to suppress polling during drag
    readonly property bool dragging: slider.dragging

    signal moved(real newValue)
    signal iconClicked()

    implicitWidth: parent ? parent.width : 240
    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            spacing: 10

            Text {
                font.family: Theme.iconFont
                font.pixelSize: root.iconSize
                color: root.muted ? Theme.red : root.accentColor
                text: root.icon

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.iconClicked()
                }
            }

            Text {
                text: root.label
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                Layout.fillWidth: true
            }

            Text {
                text: Math.round(root.value * 100) + "%"
                color: root.muted ? Theme.red : Theme.fgDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 36
            }
        }

        SliderTrack {
            id: slider
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            value: root.value
            accentColor: root.muted ? Theme.red : root.accentColor
            knobColor: root.muted ? Theme.red : Theme.fg
            trackHeight: root.trackHeight
            knobSize: root.knobSize
            onMoved: newValue => root.moved(newValue)
        }
    }
}
