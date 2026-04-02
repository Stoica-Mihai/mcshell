import QtQuick
import QtQuick.Layouts
import qs.Config

LauncherCategory {
    id: root

    // ── Launcher reference ──
    required property var launcher

    // ── Notification history model (set from AppLauncher) ──
    property var notifHistoryModel: null

    // ── Tab config ──
    tabLabel: "Notifs"
    tabIcon: Theme.iconBell
    searchPlaceholder: "Search notifications..."
    scanningState: filteredNotifs.length === 0
    scanningIcon: Theme.iconBell
    scanningHint: "No notifications"

    // ── Data ──
    model: filteredNotifs
    property var filteredNotifs: []

    // ── Lifecycle ──
    function onTabEnter() {
        launcher.notificationsViewed();
    }

    // ── Search ──
    function onSearch(text) {
        if (!notifHistoryModel) { filteredNotifs = []; return; }
        const query = (text || "").toLowerCase().trim();
        const results = [];
        for (let i = 0; i < notifHistoryModel.count; i++) {
            const item = notifHistoryModel.get(i);
            // Copy to plain JS object — ListModel references become invalid after model changes
            const copy = {
                notifId: item.notifId || "",
                appName: item.appName || "",
                summary: item.summary || "",
                body: item.body || "",
                iconUrl: item.iconUrl || "",
                urgency: item.urgency || 0,
                timestamp: item.timestamp || ""
            };
            if (query === "" || copy.summary.toLowerCase().indexOf(query) >= 0
                || copy.body.toLowerCase().indexOf(query) >= 0
                || copy.appName.toLowerCase().indexOf(query) >= 0) {
                results.push(copy);
            }
        }
        filteredNotifs = results;
    }

    // ── Activate — notifications are view-only ──
    function onActivate(index) {}

    // ── Card delegate ──
    cardDelegate: Component {
        CarouselStrip {
            selectedIndex: root.launcher.selectedIndex
            sideCount: root.launcher.sideCount
            expandedWidth: root.launcher.expandedWidth
            stripWidth: root.launcher.stripWidth
            carouselHeight: root.launcher.carouselHeight
            borderColor: isCurrent && root.launcher.editMode ? Theme.accent : Theme.border
            onSelected: root.launcher.selectedIndex = index

            // Collapsed: bell icon
            Text {
                anchors.centerIn: parent
                visible: !parent.isCurrent
                text: Theme.iconBell
                font.family: Theme.iconFont
                font.pixelSize: 24
                color: Theme.fgDim
            }

            // Expanded: notification details centered
            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - 40
                visible: parent.isCurrent
                spacing: 8

                // Image preview if available
                Rectangle {
                    id: notifPreviewContainer
                    visible: notifPreviewImg.status === Image.Ready
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Math.min(parent.width, 300)
                    Layout.preferredHeight: visible ? Layout.preferredWidth * 9 / 16 : 0
                    radius: 8
                    color: Theme.bgSolid
                    clip: true

                    Image {
                        id: notifPreviewImg
                        anchors.fill: parent
                        source: {
                            const url = modelData.iconUrl || "";
                            // Only load direct file paths — avoid image://icon/ provider
                            // which can crash with large screenshots
                            if (url.startsWith("file://"))
                                return url;
                            if (url.startsWith("/"))
                                return "file://" + url;
                            return "";
                        }
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }

                // App name + timestamp
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8

                    Text {
                        text: modelData.appName || "Notification"
                        textFormat: Text.PlainText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        color: Theme.fgDim
                    }

                    Text {
                        text: modelData.timestamp || ""
                        textFormat: Text.PlainText
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        color: Theme.fgDim
                        visible: text !== ""
                    }
                }

                // Summary
                Text {
                    Layout.fillWidth: true
                    text: modelData.summary || ""
                    textFormat: Text.PlainText
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    font.bold: true
                    color: Theme.fg
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    visible: text !== ""
                }

                // Body
                Text {
                    Layout.fillWidth: true
                    text: modelData.body || ""
                    textFormat: Text.PlainText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.fg
                    opacity: 0.85
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    maximumLineCount: 6
                    elide: Text.ElideRight
                    visible: text !== ""
                }
            }
        }
    }
}
