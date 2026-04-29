import QtQuick
import QtQuick.Shapes
import qs.Config

// Parallelogram-skewed text input. Same chrome as the launcher/weather
// search fields — SkewRect background with focus-aware stroke, optional
// leading icon glyph, placeholder, and a TextInput exposed via `field` so
// callers can attach Keys handlers.
//
// Leading icon and trailing eye sit in their own slanted compartments,
// separated from the typing area by diagonals that follow the parent
// parallelogram skew (matches the outer edges visually).
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
    property int compartmentWidth: 36

    readonly property bool _isPassword: echoMode === TextInput.Password
    readonly property bool _hasIcon: icon !== ""
    readonly property bool _hasEye: showVisibilityToggle && _isPassword
    readonly property real _skewPx: skewAmount * height / 2
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

    // Internal compartment dividers — diagonals parallel to the outer
    // slanted edges so the lock/eye look like they sit in their own slot.
    Shape {
        anchors.fill: parent
        visible: root._hasIcon
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: field.activeFocus ? Theme.accent : Theme.border
            strokeWidth: 1
            fillColor: "transparent"
            startX: root.compartmentWidth - root._skewPx
            startY: 0
            PathLine { x: root.compartmentWidth + root._skewPx; y: root.height }
        }
    }

    Shape {
        anchors.fill: parent
        visible: root._hasEye
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: field.activeFocus ? Theme.accent : Theme.border
            strokeWidth: 1
            fillColor: "transparent"
            startX: root.width - root.compartmentWidth - root._skewPx
            startY: 0
            PathLine { x: root.width - root.compartmentWidth + root._skewPx; y: root.height }
        }
    }

    // Lock compartment — icon centered within its slanted slot.
    Text {
        visible: root._hasIcon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.compartmentWidth
        horizontalAlignment: Text.AlignHCenter
        text: root.icon
        font.family: Theme.iconFont
        font.pixelSize: root.iconSize
        color: Theme.fgDim
    }

    // Eye compartment — trailing toggle, only in password mode.
    Text {
        id: eyeText
        visible: root._hasEye
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.compartmentWidth
        horizontalAlignment: Text.AlignHCenter
        text: root._revealed ? Theme.iconEyeSlash : Theme.iconEye
        font.family: Theme.iconFont
        font.pixelSize: root.iconSize
        color: eyeMouse.containsMouse ? Theme.accent : Theme.fgDim

        MouseArea {
            id: eyeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root._revealed = !root._revealed
        }
    }

    // Typing area — sits between the compartments. Margins follow the
    // compartment slot when the icon/eye is present, otherwise just inset
    // by the standard search-field padding.
    TextInput {
        id: field
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root._hasIcon
            ? root.compartmentWidth + Theme.spacingNormal
            : Theme.spacingMedium + 4
        anchors.rightMargin: root._hasEye
            ? root.compartmentWidth + Theme.spacingNormal
            : Theme.spacingMedium + 4
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
}
