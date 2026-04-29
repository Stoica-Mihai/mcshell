import QtQuick
import QtQuick.Layouts
import qs.Config

// Parallelogram-skewed text input. Same chrome as the launcher/weather
// search fields — SkewRect background with focus-aware stroke, optional
// leading icon glyph, placeholder, and a TextInput exposed via `field` so
// callers can attach Keys handlers.
//
// Password mode (echoMode: TextInput.Password) auto-centers the typed
// text and the placeholder so dots grow outward from the middle, and
// optionally renders a trailing eye toggle (showVisibilityToggle: true).
Item {
    id: root

    property alias text: field.text
    property alias field: field
    property alias passwordCharacter: field.passwordCharacter
    /// Echo mode for the inner TextInput. Aliased through a regular
    /// property (not a direct alias) so we can override it briefly when
    /// the user toggles the visibility eye.
    property int echoMode: TextInput.Normal
    property string placeholder: ""
    property string icon: ""
    property real skewAmount: -0.3
    property int iconSize: 12
    property bool showVisibilityToggle: false

    readonly property bool _isPassword: echoMode === TextInput.Password
    property bool _revealed: false

    function reset() {
        field.text = "";
        _revealed = false;
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
            // Password fields center-align so dots grow symmetrically;
            // anything else stays left-aligned.
            horizontalAlignment: root._isPassword
                ? TextInput.AlignHCenter : TextInput.AlignLeft
            // _revealed flips us into Normal echo while the eye is held
            // active; otherwise honour whatever the caller asked for.
            echoMode: root._revealed ? TextInput.Normal : root.echoMode

            Text {
                readonly property int _align: parent.horizontalAlignment
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: _align === TextInput.AlignHCenter
                    ? parent.horizontalCenter : undefined
                anchors.left: _align === TextInput.AlignLeft ? parent.left : undefined
                anchors.right: _align === TextInput.AlignRight ? parent.right : undefined
                text: root.placeholder
                color: Theme.fgDim
                font: parent.font
                visible: !parent.text
            }
        }

        Item {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: eyeText.implicitWidth
            Layout.preferredHeight: eyeText.implicitHeight
            visible: root.showVisibilityToggle && root._isPassword

            Text {
                id: eyeText
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root._revealed ? Theme.iconEyeSlash : Theme.iconEye
                font.family: Theme.iconFont
                font.pixelSize: root.iconSize
                color: eyeMouse.containsMouse ? Theme.accent : Theme.fgDim
            }

            MouseArea {
                id: eyeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root._revealed = !root._revealed
            }
        }
    }
}
