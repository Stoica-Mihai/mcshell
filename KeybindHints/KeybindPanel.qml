import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Config
import qs.Widgets

// Keybind dropdown content — hosted inside the left AnimatedPopup. Content
// only (no window): the parent dropdown owns chrome, animation, and blur.
//
// Read-only overlay: scroll the list with the mouse wheel, dismiss with
// Escape (handled by the bar's FocusScope) or by toggling the keybind
// again. No search field — the popup runs without xdg-popup grab to keep
// the parent layer-shell free of niri's input-serial requirement, which
// means a TextInput inside the popup cannot receive keyboard events.
Item {
    id: panel

    readonly property real fullHeight: 460

    KeybindParser { id: parser }

    anchors.fill: parent

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Inline header ────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 10
            Layout.bottomMargin: 8
            spacing: 8

            Text {
                text: "Keybindings"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: true
                color: Theme.fg
            }

            Item { Layout.fillWidth: true }

            Text {
                text: {
                    const n = parser.allBindings.length;
                    return n > 0 ? `niri · ${n} binding${n !== 1 ? "s" : ""}`
                                 : "loading...";
                }
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMini
                color: Theme.fgDim
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.outlineVariant
        }

        // ── Scrollable list ──────────────────────────────
        ListView {
            id: bindList
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            Layout.topMargin: 4
            clip: true
            model: parser.filteredGroups
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 3000
            maximumFlickVelocity: 4000
            spacing: 1

            SmoothWheelHandler { target: bindList }

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
                        height: 30

                        Rectangle {
                            anchors.fill: parent
                            anchors.topMargin: 4
                            anchors.bottomMargin: 2
                            color: Theme.withAlpha(Theme.accent, 0.18)
                            Rectangle {
                                width: 2
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                color: Theme.accent
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            anchors.topMargin: 4
                            anchors.bottomMargin: 2
                            spacing: 8

                            Text {
                                text: delegateLoader.modelData.icon || ""
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.accent
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                text: (delegateLoader.modelData.name || "").toUpperCase()
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeMini
                                font.bold: true
                                font.letterSpacing: 0.8
                                color: Theme.fg
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: delegateLoader.modelData.count + ""
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeMini
                                color: Theme.fgDim
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }
                }

                Component {
                    id: bindingRow

                    Rectangle {
                        width: delegateLoader.width
                        height: 28
                        color: rowHover.hovered ? Theme.bgHover : "transparent"

                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        HoverHandler { id: rowHover }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: Theme.spacingMedium

                            // Skewed key caps
                            Row {
                                Layout.preferredWidth: Math.min(170, delegateLoader.width * 0.45)
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 2
                                layoutDirection: Qt.LeftToRight

                                Repeater {
                                    model: (delegateLoader.modelData.key || "").split(" + ")

                                    Item {
                                        required property var modelData
                                        required property int index
                                        width: capRect.width
                                        height: capRect.height

                                        readonly property bool isMod: {
                                            const k = String(modelData).trim().toLowerCase();
                                            return k === "mod" || k === "ctrl" || k === "shift"
                                                || k === "alt"  || k === "super";
                                        }

                                        Rectangle {
                                            id: capRect
                                            width: capText.implicitWidth + 14
                                            height: 18
                                            color: parent.isMod ? Theme.withAlpha(Theme.secondary, 0.22)
                                                                : Theme.withAlpha(Theme.accent, 0.22)
                                            border.width: 1
                                            border.color: parent.isMod ? Theme.withAlpha(Theme.secondary, 0.55)
                                                                       : Theme.withAlpha(Theme.accent, 0.55)
                                            transform: Matrix4x4 {
                                                matrix: Qt.matrix4x4(
                                                    1, Math.tan(-0.21), 0, Math.tan(-0.21) * capRect.height / 2,
                                                    0, 1, 0, 0,
                                                    0, 0, 1, 0,
                                                    0, 0, 0, 1)
                                            }

                                            Text {
                                                id: capText
                                                anchors.centerIn: parent
                                                text: parent.parent.modelData.trim()
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeMini
                                                font.bold: true
                                                color: Theme.fg
                                                transform: Matrix4x4 {
                                                    matrix: Qt.matrix4x4(
                                                        1, Math.tan(0.21), 0, Math.tan(0.21) * capText.height / -2,
                                                        0, 1, 0, 0,
                                                        0, 0, 1, 0,
                                                        0, 0, 0, 1)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                text: Theme.iconArrowTo
                                font.pixelSize: Theme.fontSizeMini
                                color: Theme.fgDim
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: delegateLoader.modelData.action || ""
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.fg
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }

        // ── Footer ───────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.outlineVariant
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 10
            Layout.topMargin: 8
            spacing: 6

            Text {
                text: "live · niri/config.kdl"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMini
                color: Theme.fgDim
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "ESC close"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMini
                color: Theme.fgDim
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
