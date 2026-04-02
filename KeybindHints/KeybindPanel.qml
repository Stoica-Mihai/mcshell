import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Config

PanelWindow {
    id: panel

    // ── Public API ──────────────────────────────────────
    property bool isOpen: false

    function open() {
        isOpen = true;
        visible = true;
        searchField.text = "";
        searchField.forceActiveFocus();
        if (parser.allBindings.length === 0) parser.loadBindings();
    }

    function close() {
        isOpen = false;
        visible = false;
        searchField.text = "";
    }

    function toggle() {
        if (isOpen) close(); else open();
    }

    // ── Window setup ────────────────────────────────────
    visible: false
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "mcshell-keybinds"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    // ── Parser ──────────────────────────────────────────
    KeybindParser {
        id: parser
        filterText: searchField.text
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
        radius: 12
        color: Theme.bg
        border.width: 1
        border.color: Theme.border
        clip: true

        ColumnLayout {
            id: cardColumn
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // ── Header row ──────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: Theme.iconKeyboard
                    font.family: Theme.iconFont
                    font.pixelSize: 18
                    color: Theme.accent
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: "Keybindings"
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
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
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 8
                color: Theme.bgSolid
                border.width: 1
                border.color: searchField.activeFocus ? Theme.accent : Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Image {
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignVCenter
                        sourceSize.width: 16
                        sourceSize.height: 16
                        source: "image://icon/edit-find"
                        opacity: 0.5
                    }

                    TextInput {
                        id: searchField
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        color: Theme.fg
                        clip: true
                        selectByMouse: true

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                panel.close();
                                event.accepted = true;
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Filter keybindings..."
                            color: Theme.fgDim
                            font: parent.font
                            visible: !parent.text
                        }
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

                // Fast mouse wheel scrolling
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        bindList.contentY = Math.max(
                            0,
                            Math.min(bindList.contentHeight - bindList.height,
                                     bindList.contentY - event.angleDelta.y * 1.5)
                        );
                    }
                }
                spacing: 0

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    width: 6

                    contentItem: Rectangle {
                        implicitWidth: 6
                        radius: 3
                        color: Theme.fgDim
                        opacity: 0.4
                    }
                }

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
                                spacing: 8

                                Text {
                                    text: delegateLoader.modelData.icon || ""
                                    font.family: Theme.iconFont
                                    font.pixelSize: 14
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
                            radius: 6
                            color: rowHover.hovered ? Theme.bgHover : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: Theme.animFast }
                            }

                            HoverHandler {
                                id: rowHover
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 12

                                // Key caps
                                Row {
                                    Layout.preferredWidth: Math.min(280, delegateLoader.width * 0.42)
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 4
                                    layoutDirection: Qt.LeftToRight

                                    Repeater {
                                        model: (delegateLoader.modelData.key || "").split(" + ")

                                        Rectangle {
                                            required property var modelData
                                            required property int index
                                            width: capText.implicitWidth + 14
                                            height: 22
                                            radius: 4
                                            color: Qt.rgba(
                                                Theme.accent.r,
                                                Theme.accent.g,
                                                Theme.accent.b,
                                                0.12
                                            )
                                            border.width: 1
                                            border.color: Qt.rgba(
                                                Theme.accent.r,
                                                Theme.accent.g,
                                                Theme.accent.b,
                                                0.25
                                            )

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
                    if (searchField.text && shown === 0) return "No matching keybindings";
                    if (searchField.text) return shown + " of " + total + " keybindings";
                    return total + " keybinding" + (total !== 1 ? "s" : "") + " from niri config";
                }
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.fgDim
            }
        }
    }
}
