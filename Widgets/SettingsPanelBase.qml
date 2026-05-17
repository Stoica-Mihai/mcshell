import QtQuick
import QtQuick.Layouts
import qs.Config

// Shared scaffold for bar settings popups (Clock, SysInfo, Wifi, Bluetooth).
//
// Owns the FocusScope, KeyboardRowNav, focus management (reset on open,
// forceActiveFocus), the standard Up/Down/Left/Right/Return/Space key
// bindings, and the `fullHeight` measurement convention used by the bar
// dropdown loaders.
//
// Consumers declare row descriptors via the `rows` property and place
// their UI as child items — children are reparented into an internal
// ColumnLayout (`content`) so `fullHeight` is measured uniformly:
//
//   SettingsPanelBase {
//       rows: root._rows
//       Text { ... }
//       Repeater { model: root._rows; SettingsCheckRow { ... } }
//   }
//
// Left/Right are wired to `nav.adjust()` unconditionally; for check-only
// popups this is a no-op (check rows have no `values` / `onAdjust`), so
// the base stays uniform across all four popups.
FocusScope {
    id: root

    // Set by the hosting Loader / dropdown so we can reset selection +
    // refocus when the popup actually opens.
    property bool windowOpen: false

    // Row descriptor array forwarded to KeyboardRowNav. Same shape as
    // documented in Widgets/KeyboardRowNav.qml.
    property var rows: []

    // Spacing around the content column — popups can override if they
    // need a different inset (default matches the four current popups).
    property int contentMargins: Theme.spacingNormal
    property int contentSpacing: Theme.spacingSmall

    // Child items become the rows of the internal ColumnLayout.
    default property alias contentData: content.data

    readonly property real fullHeight: content.implicitHeight + contentMargins * 2
    readonly property alias nav: nav
    readonly property alias selectedRow: nav.selectedRow
    readonly property alias rowCount: nav.rowCount

    anchors.fill: parent
    focus: true

    onWindowOpenChanged: if (windowOpen) { nav.reset(); forceActiveFocus(); }

    KeyboardRowNav {
        id: nav
        rows: root.rows
    }

    Keys.onUpPressed:     nav.navigate(-1)
    Keys.onDownPressed:   nav.navigate(1)
    Keys.onLeftPressed:   nav.adjust(-1)
    Keys.onRightPressed:  nav.adjust(1)
    Keys.onReturnPressed: nav.activate()
    Keys.onSpacePressed:  nav.activate()

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: root.contentMargins
        spacing: root.contentSpacing
    }
}
