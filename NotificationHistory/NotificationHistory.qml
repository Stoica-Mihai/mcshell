import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Config
import qs.Widgets

// Notification history dropdown — anchored to the bell icon in the bar.
AnimatedPopup {
    id: panel

    // ── Public API ──────────────────────────────────────
    property var historyModel: null

    signal removeFromHistory(string nid)
    signal clearAllHistory()

    implicitWidth: 340

    readonly property int maxVisibleEntries: 4
    readonly property int entryHeight: 60
    readonly property int headerHeight: 80

    // Reactive binding — auto-resizes with content
    fullHeight: {
        if (!historyModel || historyModel.count === 0)
            return headerHeight + 80;
        const visibleCount = Math.min(maxVisibleEntries, historyModel.count);
        return headerHeight + visibleCount * entryHeight;
    }

    function showAt(anchorItem) {
        anchor.item = anchorItem;
        anchor.rect.x = -(implicitWidth - anchorItem.width);
        anchor.rect.y = (Theme.barHeight + anchorItem.height) / 2 - 2;
        open();
    }

    // ── Background ──────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: Theme.barRadius
        bottomRightRadius: Theme.barRadius
        color: Theme.bgSolid
        border.width: 1
        border.color: Theme.border
        clip: true

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 1
            anchors.rightMargin: 1
            height: 2
            color: Theme.bgSolid
        }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── Header ──────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: Theme.iconBell
                    font.family: Theme.iconFont
                    font.pixelSize: 14
                    color: Theme.accent
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: "Notifications"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.Medium
                    color: Theme.fg
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }

                // Clear All
                Rectangle {
                    visible: panel.historyModel && panel.historyModel.count > 0
                    Layout.alignment: Qt.AlignVCenter
                    width: clearRow.implicitWidth + 12
                    height: 22
                    radius: 4
                    color: clearMouse.containsMouse ? Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, 0.15) : "transparent"

                    RowLayout {
                        id: clearRow
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: Theme.iconTrash
                            font.family: Theme.iconFont
                            font.pixelSize: 10
                            color: clearMouse.containsMouse ? Theme.red : Theme.fgDim
                        }

                        Text {
                            text: "Clear"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: clearMouse.containsMouse ? Theme.red : Theme.fgDim
                        }
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.clearAllHistory()
                    }
                }
            }

            // ── Separator ───────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

            // ── Empty state ─────────────────────────────
            Item {
                visible: !panel.historyModel || panel.historyModel.count === 0
                Layout.fillWidth: true
                implicitHeight: emptyCol.implicitHeight + 48

                ColumnLayout {
                    id: emptyCol
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: Theme.iconBellSlash
                        font.family: Theme.iconFont
                        font.pixelSize: 24
                        color: Theme.fgDim
                        opacity: 0.5
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "No notifications"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.fgDim
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }
                }
            }

            // ── Notification list ───────────────────────
            ListView {
                id: historyList
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: panel.historyModel && panel.historyModel.count > 0
                clip: true
                model: panel.historyModel
                boundsBehavior: Flickable.StopAtBounds
                spacing: 4

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        historyList.contentY = Math.max(
                            0,
                            Math.min(historyList.contentHeight - historyList.height,
                                     historyList.contentY - event.angleDelta.y * 1.5)
                        );
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    width: 4

                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 2
                        color: Theme.fgDim
                        opacity: 0.4
                    }
                }

                delegate: Rectangle {
                    id: entryItem

                    width: historyList.width - 4
                    height: entryContent.implicitHeight + 14
                    radius: 6
                    color: entryHover.hovered ? Theme.bgHover : "transparent"

                    HoverHandler {
                        id: entryHover
                    }

                    // Urgency accent bar
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.topMargin: 3
                        anchors.bottomMargin: 3
                        width: 2
                        radius: 1
                        color: model.urgency === 2 ? Theme.red
                             : model.urgency === 0 ? Theme.fgDim
                             :                       Theme.accent
                    }

                    ColumnLayout {
                        id: entryContent
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                            margins: 7
                            leftMargin: 10
                        }
                        spacing: 2

                        // Header
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: model.appName || "Notification"
                                color: Theme.fgDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: model.timestamp || ""
                                color: Theme.fgDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                            }

                            IconButton {
                                icon: Theme.iconClose
                                size: 10
                                normalColor: Theme.fgDim
                                hoverColor: Theme.red
                                visible: entryHover.hovered
                                onClicked: panel.removeFromHistory(model.notifId)
                            }
                        }

                        // Summary
                        Text {
                            visible: text.length > 0
                            text: model.summary
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            maximumLineCount: 1
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        // Body
                        Text {
                            visible: text.length > 0
                            text: model.body
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            opacity: 0.7
                        }
                    }
                }
            }

            // "N more" indicator when list is scrollable
            Text {
                visible: panel.historyModel
                      && panel.historyModel.count > panel.maxVisibleEntries
                      && historyList.contentHeight > historyList.height
                      && historyList.contentY + historyList.height < historyList.contentHeight - 5
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: {
                    if (!panel.historyModel) return "";
                    const hidden = panel.historyModel.count - panel.maxVisibleEntries;
                    if (hidden <= 0) return "";
                    return "\u25BC " + hidden + " more";
                }
                font.family: Theme.fontFamily
                font.pixelSize: 9
                color: Theme.fgDim
                opacity: 0.7
                Layout.topMargin: 2
            }
        }
    }
}
