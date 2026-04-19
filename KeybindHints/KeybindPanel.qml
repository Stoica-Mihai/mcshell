import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Core
import qs.Widgets

OverlayWindow {
    id: panel
    namespace: "mcshell-keybinds"

    // Always-visible layer-shell surface — see AppLauncher for why.
    visible: true
    mask: isOpen ? null : _emptyRegion
    focusMode: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Region { id: _emptyRegion }

    // ── Public API ──────────────────────────────────────
    property bool isOpen: false

    property int selectedIndex: -1

    function open() {
        isOpen = true;
        searchArea.reset();
        selectedIndex = -1;
    }

    function close() {
        isOpen = false;
        searchArea.text = "";
    }

    function toggle() {
        if (isOpen) close(); else open();
    }

    function navigate(dir) {
        const groups = parser.filteredGroups;
        let i = selectedIndex + dir;
        // Skip section headers
        while (i >= 0 && i < groups.length && groups[i].isHeader) i += dir;
        if (i < 0 || i >= groups.length) return;
        selectedIndex = i;
        bindList.positionViewAtIndex(i, ListView.Contain);
    }

    function navigateDown() { navigate(1); }
    function navigateUp() { navigate(-1); }

    // ── Window setup ────────────────────────────────────
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // ── Parser ──────────────────────────────────────────
    KeybindParser {
        id: parser
        filterText: searchArea.text
        onFilteredGroupsChanged: panel.selectedIndex = -1
    }

    // ── UI ──────────────────────────────────────────────

    // Semi-transparent dimmer -- click to close
    Rectangle {
        anchors.fill: parent
        color: Theme.backdrop

        MouseArea {
            anchors.fill: parent
            onClicked: panel.close()
        }
    }

    // Centered card
    Rectangle {
        id: card
        width: Math.min(700, parent.width * 0.85)
        height: parent.height * 0.82
        anchors.centerIn: parent
        radius: Theme.dialogRadius
        color: Theme.bg
        border.width: 1
        border.color: Theme.border
        clip: true

        ColumnLayout {
            id: cardColumn
            anchors.fill: parent
            anchors.margins: 16
            spacing: Theme.spacingLarge

            // ── Header row ──────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMedium

                Text {
                    text: Theme.iconKeyboard
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSizeXLarge
                    color: Theme.accent
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: "Keybindings"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMedium
                    font.bold: true
                    color: Theme.fg
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "ESC to close"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.fgDim
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            // ── Search field ────────────────────────────
            StyledTextField {
                id: searchArea
                Layout.fillWidth: true
                icon: Theme.iconSearch
                placeholder: "Filter keybindings..."

                field.Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        panel.close();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down) {
                        panel.navigateDown();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        panel.navigateUp();
                        event.accepted = true;
                    }
                }
            }

            // ── Scrollable keybind list ─────────────────
            ListView {
                id: bindList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: parser.filteredGroups
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 3000
                maximumFlickVelocity: 4000

                SmoothWheelHandler { target: bindList }
                spacing: 0

                ScrollBar.vertical: ThemedScrollBar {}

                delegate: Loader {
                    id: delegateLoader
                    required property var modelData
                    required property int index
                    width: bindList.width

                    sourceComponent: modelData.isHeader ? sectionHeader : bindingRow

                    Component {
                        id: sectionHeader

                        Item {
                            width: delegateLoader.width
                            height: 40

                            RowLayout {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: 4
                                anchors.rightMargin: 4
                                anchors.bottomMargin: 4
                                spacing: Theme.spacingNormal

                                Text {
                                    text: delegateLoader.modelData.icon || ""
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.fontSizeBody
                                    color: Theme.accent
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Text {
                                    text: delegateLoader.modelData.name || ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                    font.bold: true
                                    color: Theme.accent
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    height: 1
                                    color: Theme.border
                                }

                                Text {
                                    text: delegateLoader.modelData.count + ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.fgDim
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.rightMargin: 4
                                }
                            }
                        }
                    }

                    Component {
                        id: bindingRow

                        Rectangle {
                            width: delegateLoader.width
                            height: 34
                            radius: Theme.radiusSmall
                            color: delegateLoader.index === panel.selectedIndex ? Theme.overlayHover
                                 : rowHover.hovered ? Theme.bgHover : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: Theme.animFast }
                            }

                            HoverHandler {
                                id: rowHover
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingNormal
                                anchors.rightMargin: Theme.spacingNormal
                                spacing: Theme.spacingLarge

                                // Key caps
                                Row {
                                    Layout.preferredWidth: Math.min(280, delegateLoader.width * 0.42)
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: Theme.spacingTiny
                                    layoutDirection: Qt.LeftToRight

                                    Repeater {
                                        model: (delegateLoader.modelData.key || "").split(" + ")

                                        Rectangle {
                                            required property var modelData
                                            required property int index
                                            width: capText.implicitWidth + 14
                                            height: 22
                                            radius: Theme.radiusTiny
                                            color: Theme.accentLight
                                            border.width: 1
                                            border.color: Theme.accentBorder

                                            Text {
                                                id: capText
                                                anchors.centerIn: parent
                                                text: modelData.trim()
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.bold: true
                                                color: Theme.accent
                                            }
                                        }
                                    }
                                }

                                // Arrow separator
                                Text {
                                    text: Theme.iconArrowTo
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.fgDim
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                // Action description
                                Text {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    text: delegateLoader.modelData.action || ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                    color: Theme.fg
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }

            // ── Footer ──────────────────────────────────
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: {
                    const total = parser.allBindings.length;
                    if (total === 0) return "Loading keybindings...";
                    let shown = 0;
                    for (let i = 0; i < parser.filteredGroups.length; i++) {
                        if (!parser.filteredGroups[i].isHeader) shown++;
                    }
                    if (searchArea.text && shown === 0) return "No matching keybindings";
                    if (searchArea.text) return `${shown} of ${total} keybindings`;
                    return `${total} keybinding${total !== 1 ? "s" : ""} from niri config`;
                }
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.fgDim
            }
        }
    }
}
