import QtQuick
import QtQuick.Layouts
import qs.Config

// Parallelogram-skewed text input. Same chrome as the launcher/weather
// search fields — SkewRect background with focus-aware stroke, optional
// leading icon glyph, placeholder, and a TextInput exposed via `field` so
// callers can attach Keys handlers.
Item {
    id: root

    property alias text: field.text
    property alias field: field
    property alias echoMode: field.echoMode
    property alias passwordCharacter: field.passwordCharacter
    property string placeholder: ""
    property string icon: ""
    property real skewAmount: -0.3
    property int iconSize: 12

    function reset() {
        field.text = "";
        field.forceActiveFocus();
    }

    implicitHeight: 28

    SkewRect {
        anchors.fill: parent
        fillColor: Theme.withAlpha(Theme.fg, 0.04)
        strokeColor: field.activeFocus ? Theme.accent : Theme.border
        strokeWidth: 1
        skewAmount: root.skewAmount
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingMedium + 4
        anchors.rightMargin: Theme.spacingMedium + 4
        spacing: Theme.spacingNormal

        Text {
            visible: root.icon !== ""
            text: root.icon
            font.family: Theme.iconFont
            font.pixelSize: root.iconSize
            color: Theme.fgDim
            Layout.alignment: Qt.AlignVCenter
        }

        TextInput {
            id: field
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            clip: true
            selectByMouse: true

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.placeholder
                color: Theme.fgDim
                font: parent.font
                visible: !parent.text
            }
        }
    }
}
