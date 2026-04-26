import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Config
import qs.Core
import qs.Widgets
import qs.Bar

// Keybind dropdown — flush under the left bar segment, same chrome as
// Calendar / Weather popups. Reassigns screen to niri's focused output on
// open so the dropdown follows multi-monitor focus.
BarPopupWindow {
    id: panel
    namespace: Namespaces.keybinds
    cardAlignment: "left"
    cardWidth: Theme.barSideWidth - Theme.barDiagSlant
    cardHeight: 460
    wantsKeyboardFocus: true

    property int selectedIndex: -1

    onIsOpenChanged: {
        if (isOpen) {
            const s = FocusedOutput.screen;
            if (s && panel.screen !== s) panel.screen = s;
            searchField.text = "";
            selectedIndex = -1;
            focusTimer.restart();
        }
    }

    Timer {
        id: focusTimer
        interval: Theme.animSmooth + 50
        onTriggered: if (panel.isOpen) searchField.field.forceActiveFocus()
    }

    function navigate(dir) {
        const groups = parser.filteredGroups;
        let i = selectedIndex + dir;
        while (i >= 0 && i < groups.length && groups[i].isHeader) i += dir;
        if (i < 0 || i >= groups.length) return;
        selectedIndex = i;
        bindList.positionViewAtIndex(i, ListView.Contain);
    }

    KeybindParser {
        id: parser
        filterText: searchField.text
        onFilteredGroupsChanged: panel.selectedIndex = -1
    }

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

        SkewTextField {
            id: searchField
            Layout.fillWidth: true
            Layout.leftMargin: Theme.spacingLarge
            Layout.rightMargin: Theme.spacingLarge
            Layout.topMargin: 8
            Layout.bottomMargin: 4
            icon: Theme.iconSearch
            placeholder: "Filter keybindings..."

            field.Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    panel.close();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down) {
                    panel.navigate(1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    panel.navigate(-1);
                    event.accepted = true;
                }
            }
        }

        // ── Scrollable list ──────────────────────────────
        ListView {
            id: bindList
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 6
            Layout.rightMargin: 6
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
                        color: delegateLoader.index === panel.selectedIndex ? Theme.overlayHover
                             : rowHover.hovered ? Theme.bgHover : "transparent"

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
                text: {
                    const total = parser.allBindings.length;
                    let shown = 0;
                    for (let i = 0; i < parser.filteredGroups.length; i++) {
                        if (!parser.filteredGroups[i].isHeader) shown++;
                    }
                    if (searchField.text && shown === 0) return "no match";
                    if (searchField.text) return `${shown} / ${total}`;
                    return "ESC close";
                }
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMini
                color: Theme.fgDim
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
