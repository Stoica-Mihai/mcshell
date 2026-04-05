import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Config
import qs.Widgets

// Notification history content panel.
// Meant to be hosted inside a shared dropdown.
Item {
    id: panel

    // ── Public API ──────────────────────────────────────
    property var historyModel: null

    signal removeFromHistory(string nid)
    signal clearAllHistory()

    readonly property int maxVisibleEntries: 4
    readonly property int entryHeight: 60
    readonly property int headerHeight: 80

    // Height the host dropdown should use
    readonly property int fullHeight: {
        if (!historyModel || historyModel.count === 0)
            return headerHeight + 80;
        const visibleCount = Math.min(maxVisibleEntries, historyModel.count);
        return headerHeight + visibleCount * entryHeight;
    }

    anchors.fill: parent

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Theme.popupPadding
        spacing: Theme.spacingNormal

        // ── Header ──────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingNormal

            Text {
                text: Theme.iconBell
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSizeBody
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
            IconButton {
                visible: panel.historyModel && panel.historyModel.count > 0
                icon: Theme.iconTrash
                size: 14
                implicitWidth: 32
                implicitHeight: 24
                normalColor: Theme.fgDim
                hoverColor: Theme.red
                onClicked: panel.clearAllHistory()
            }
        }

        // ── Separator ───────────────────────────────
        Separator {}

        // ── Empty state ─────────────────────────────
        Item {
            visible: !panel.historyModel || panel.historyModel.count === 0
            Layout.fillWidth: true
            implicitHeight: emptyCol.implicitHeight + 48

            ColumnLayout {
                id: emptyCol
                anchors.centerIn: parent
                spacing: Theme.spacingNormal

                Text {
                    text: Theme.iconBellSlash
                    font.family: Theme.iconFont
                    font.pixelSize: 24
                    color: Theme.fgDim
                    opacity: Theme.opacityMuted
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
            spacing: Theme.spacingTiny

            SmoothWheelHandler { target: historyList }

            ScrollBar.vertical: ThemedScrollBar { barWidth: 4 }

            delegate: Rectangle {
                id: entryItem

                width: historyList.width - 4
                height: entryContent.implicitHeight + 14
                radius: Theme.radiusSmall
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
                    color: Theme.urgencyColor(model.urgency)
                }

                ColumnLayout {
                    id: entryContent
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: 7
                        leftMargin: Theme.spacingMedium
                    }
                    spacing: 2

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingSmall

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
                            font.pixelSize: Theme.fontSizeMini
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
                        font.pixelSize: Theme.fontSizeTiny
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        opacity: Theme.opacitySecondary
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
            font.pixelSize: Theme.fontSizeMini
            color: Theme.fgDim
            opacity: Theme.opacitySecondary
            Layout.topMargin: 2
        }
    }
}
