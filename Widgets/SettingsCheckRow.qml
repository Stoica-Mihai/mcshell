import QtQuick
import QtQuick.Layouts
import qs.Config

// Skewed-morphism check row for settings popups: selection-stripe bg +
// SkewCheck mirroring a UserSettings boolean + label.
Item {
    id: root

    property string label: ""
    property string setting: ""
    property bool selected: false

    Layout.fillWidth: true
    Layout.preferredHeight: 24

    SkewRect {
        anchors.fill: parent
        fillColor: Theme.withAlpha(Theme.accent, 0.08)
        visible: root.selected
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingMedium
        anchors.rightMargin: Theme.spacingMedium
        spacing: Theme.spacingNormal

        SkewCheck { checked: root.setting !== "" && UserSettings[root.setting] }
        Text {
            text: root.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.fg
            Layout.fillWidth: true
        }
    }
}
