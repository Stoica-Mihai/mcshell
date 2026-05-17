import QtQuick
import QtQuick.Layouts
import qs.Config

// Skewed-morphism row with label + right-aligned control slot, used by
// settings popups for rows whose right-hand widget is a CyclePicker /
// SkewToggle (i.e. SettingsCheckRow doesn't fit because the control
// isn't a SkewCheck).
//
//   SettingsRowSlot {
//       selected: root.selectedRow === 3
//       label: "Bar metric"
//       CyclePicker { ... }
//   }
//
// Selection draws the standard accent-tinted parallelogram fill plus a
// thin accent stripe flush against the left edge — same visual as the
// inline `SettingRowBase` previously duplicated in SysInfoSettingsPopup.
Item {
    id: root

    property bool selected: false
    property string label: ""

    // Child items go into the right-hand controls slot. Typically one
    // CyclePicker or SkewToggle, but a small RowLayout would also work.
    default property alias controls: controlsHolder.data

    Layout.fillWidth: true
    Layout.preferredHeight: 26

    // Selection fill (parallelogram tint).
    SkewRect {
        anchors.fill: parent
        fillColor: Theme.withAlpha(Theme.accent, 0.08)
        visible: root.selected
    }

    // Left accent stripe — matches the bar capsule's selection idiom.
    SkewRect {
        x: 2
        y: 4
        width: 2
        height: parent.height - 8
        fillColor: Theme.accent
        visible: root.selected
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingLarge
        anchors.rightMargin: Theme.spacingMedium

        Text {
            text: root.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.fg
            Layout.fillWidth: true
        }

        // `Row` rather than plain Item so the slot's implicit size tracks
        // only the visible child — SysInfo rows have one control, Clock
        // toggles between CyclePicker and SkewToggle by `visible:`. Plain
        // Item + childrenRect would size to the wider child regardless of
        // visibility and leave the active control floating mid-row.
        Row {
            id: controlsHolder
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
