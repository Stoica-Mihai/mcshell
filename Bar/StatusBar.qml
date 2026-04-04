import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Widgets
import qs.NotificationHistory

Scope {
    id: root

    property string screenName: ""
    property var screen: null
    property bool hasPopup: capsule.activePanel !== "" || clock.popupVisible || sysTray.menuVisible || media.popupVisible

    property int unreadNotifications: 0
    property var notifHistoryModel: null
    signal launcherRequested()
    signal notifRemoved(string nid)
    signal notifCleared()
    signal notifPanelOpened()

    property bool mediaPlaying: false

    property int panelToggleTrigger: 0
    property string panelToggleName: ""
    onPanelToggleTriggerChanged: {
        if (panelToggleName === "calendar") clock.togglePopup();
        else if (panelToggleName) capsule.togglePanel(panelToggleName);
    }

    function dismissPopups() {
        capsule.closePanel();
        clock.dismissPopup();
        sysTray.dismissMenu();
        media.dismissPopup();
    }

    // ── Exclusive zone — reserves bar space, no content ────
    PanelWindow {
        id: exclusionZone
        screen: root.screen
        color: "transparent"
        visible: true

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: Theme.barHeight + Theme.barMargin * 2
        exclusiveZone: Theme.barHeight + Theme.barMargin * 2

        // Prevent auto-lock during media playback
        IdleInhibitor {
            window: exclusionZone
            enabled: root.mediaPlaying
        }

        WlrLayershell.namespace: "mcshell-zone"
        WlrLayershell.layer: WlrLayer.Top
    }

    // ── Main surface — fullscreen, contains bar + dismiss area ──
    // Single surface so clicks on bar elements take priority over
    // the dismiss area. No separate clickCatcher needed.
    PanelWindow {
        id: mainSurface

        screen: root.screen
        color: "transparent"
        visible: true

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        WlrLayershell.namespace: "mcshell"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        // Input mask: bar only when no popup, fullscreen when popup is open.
        // Without this, the fullscreen transparent window blocks all input below.
        Item { id: fullSurface; anchors.fill: parent }
        mask: Region {
            item: root.hasPopup ? fullSurface : barRect
        }

        // ── Dismiss area — behind everything, catches outside clicks ──
        MouseArea {
            anchors.fill: parent
            visible: root.hasPopup
            onClicked: root.dismissPopups()
        }

        // ── Bar content — positioned at top ──────────────────
        Rectangle {
            id: barRect
            x: Theme.barMargin + 1
            y: Theme.barMargin
            width: parent.width - (Theme.barMargin + 1) * 2
            height: Theme.barHeight
            radius: Theme.barRadius
            color: Theme.bg
            border.width: 1
            border.color: Theme.border

            // Clock — absolutely centered on bar, independent of left/right content
            Clock {
                id: clock
                anchors.centerIn: parent
                z: 1
            }

            // Recording indicator — pulsing red dot left of clock
            Rectangle {
                visible: root.isRecording
                anchors.right: clock.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 8; height: 8; radius: 4
                color: Theme.red
                z: 1

                SequentialAnimation on opacity {
                    running: root.isRecording
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: Theme.animLockFade }
                    NumberAnimation { to: 1.0; duration: Theme.animLockFade }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 0

                // Left: launcher button + workspaces + window title
                IconButton {
                    icon: Theme.iconSearch
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: 10
                    onClicked: root.launcherRequested()
                }

                Workspaces {
                    Layout.alignment: Qt.AlignVCenter
                    screenName: root.screenName
                }

                ActiveWindow {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 10
                    Layout.maximumWidth: 300
                }

                Item { Layout.fillWidth: true }

                // Right: media, tray, then system capsule
                RowLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Theme.itemSpacing

                    Media {
                        id: media
                        Layout.alignment: Qt.AlignVCenter
                    }

                    SysTray {
                        id: sysTray
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // ── System capsule ─────────────────────
                    Item {
                        id: capsule
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: capsuleRow.implicitWidth + 16
                        implicitHeight: Theme.barHeight - 10

                        property string activePanel: ""  // "volume", "notifications"

                        function togglePanel(name) {
                            if (activePanel === name) {
                                closePanel();
                            } else {
                                sharedDropdown.close();
                                activePanel = name;
                                sharedDropdown.anchor.item = bellIcon;
                                var barRightPadding = 12 + Theme.barMargin + 2;
                                sharedDropdown.anchor.rect.x = -(sharedDropdown.implicitWidth - bellIcon.width - barRightPadding);
                                sharedDropdown.open();
                            }
                        }

                        function closePanel() {
                            sharedDropdown.close();
                        }

                        // Capsule background
                        Rectangle {
                            anchors.fill: parent
                            radius: (Theme.barHeight - 10) / 2
                            color: capsule.activePanel !== "" ? Theme.bgHover : "transparent"
                            border.width: capsule.activePanel !== "" ? 1 : 0
                            border.color: Theme.border

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        }

                        RowLayout {
                            id: capsuleRow
                            anchors.centerIn: parent
                            spacing: Theme.spacingMedium

                            // Volume
                            CapsuleItem {
                                icon: Theme.volumeIcon(volume.rawVolume, volume.muted)
                                label: volume.volume + "%"
                                alert: volume.muted
                                active: capsule.activePanel === "volume"
                                onClicked: event => {
                                    if (event.button === Qt.MiddleButton)
                                        volume.toggleMute();
                                    else
                                        capsule.togglePanel("volume");
                                }
                                onWheel: event => {
                                    const step = Theme.volumeStep;
                                    if (event.angleDelta.y > 0)
                                        volume.setVolume(volume.rawVolume + step);
                                    else
                                        volume.setVolume(volume.rawVolume - step);
                                }

                                // VU peak bar
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: -2
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width * Math.min(1.0, volume.peak)
                                    height: 2
                                    radius: 1
                                    color: volume.muted ? Theme.red : Theme.accent
                                    opacity: volume.peak > 0.01 ? 0.8 : 0
                                }
                            }

                            // Battery
                            CapsuleItem {
                                visible: battery.present
                                icon: Theme.batteryIcon(battery.percentage, battery.charging)
                                label: battery.percentage + "%"
                                alert: battery.low
                            }

                            // Notification bell
                            Item {
                                id: bellIcon
                                implicitWidth: Theme.iconSize
                                implicitHeight: Theme.iconSize

                                Text {
                                    anchors.centerIn: parent
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.iconSize
                                    color: UserSettings.doNotDisturb ? Theme.red
                                         : bellMouse2.containsMouse ? Theme.accent
                                         : root.unreadNotifications > 0 ? Theme.accent
                                         : Theme.fg
                                    text: UserSettings.doNotDisturb ? Theme.iconDndOn : Theme.iconBell
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                }

                                // Underline
                                Rectangle {
                                    visible: capsule.activePanel === "notifications"
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: -4
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width + 4
                                    height: 2
                                    radius: 1
                                    color: Theme.accent
                                }

                                // Unread badge
                                Rectangle {
                                    visible: root.unreadNotifications > 0 && !UserSettings.doNotDisturb
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.topMargin: -3
                                    anchors.rightMargin: -5
                                    width: Math.max(14, badgeText.implicitWidth + 6)
                                    height: 14
                                    radius: 7
                                    color: Theme.yellow
                                    z: 10

                                    Text {
                                        id: badgeText
                                        anchors.centerIn: parent
                                        text: root.unreadNotifications > 99 ? "99+" : root.unreadNotifications
                                        color: Theme.bgSolid
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeMini
                                        font.bold: true
                                    }
                                }

                                MouseArea {
                                    id: bellMouse2
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                    onClicked: event => {
                                        if (event.button === Qt.MiddleButton)
                                            UserSettings.doNotDisturb = !UserSettings.doNotDisturb;
                                        else
                                            capsule.togglePanel("notifications");
                                    }
                                }
                            }

                        }

                        // ── Shared dropdown ───────────────
                        AnimatedPopup {
                            id: sharedDropdown

                            implicitWidth: capsule.activePanel === "notifications" ? 340 : 280

                            fullHeight: {
                                if (capsule.activePanel === "volume")
                                    return volumeContent.implicitHeight + Theme.popupPadding * 2;
                                if (capsule.activePanel === "notifications")
                                    return notifContent.fullHeight;
                                return 100;
                            }

                            onVisibleChanged: {
                                if (!visible) capsule.activePanel = "";
                            }

                            // Volume section
                            ColumnLayout {
                                id: volumeContent
                                visible: capsule.activePanel === "volume"
                                enabled: visible
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: Theme.popupPadding
                                spacing: Theme.spacingTiny

                                VolumeSlider {
                                    Layout.fillWidth: true
                                    Layout.bottomMargin: 2
                                }

                                Rectangle {
                                    visible: appVolume.hasStreams
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 1
                                    color: Theme.border
                                }

                                AppVolume {
                                    id: appVolume
                                    Layout.fillWidth: true
                                }
                            }

                            // Notifications section
                            NotificationHistory {
                                id: notifContent
                                visible: capsule.activePanel === "notifications"
                                historyModel: root.notifHistoryModel
                                onRemoveFromHistory: nid => root.notifRemoved(nid)
                                onClearAllHistory: root.notifCleared()
                                onVisibleChanged: {
                                    if (visible) root.notifPanelOpened();
                                }
                            }

                        }
                    }
                }
            }
        }
    }

    // Recording state (passed from shell.qml)
    property bool isRecording: false
    signal toggleRecording()

    // Volume state — kept at root level for accessibility
    Volume {
        id: volume
        visible: false
    }

    // Battery state
    Battery {
        id: battery
        visible: false
    }
}
