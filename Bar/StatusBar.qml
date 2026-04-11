import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.SystemTray
import qs.Config
import qs.Widgets
import qs.NotificationHistory

Scope {
    id: root

    property string screenName: ""
    property var screen: null
    property bool hasPopup: sharedDropdown.activePanel !== ""
        || calendarWindow.isOpen
        || weatherWindow.isOpen
        || clockSettingsWindow.isOpen

    property int unreadNotifications: 0
    property var notifHistoryModel: null
    signal launcherRequested()
    signal wifiRequested()
    signal bluetoothRequested()
    signal notifRemoved(string nid)
    signal notifCleared()
    signal notifPanelOpened()

    property bool mediaPlaying: false

    property int panelToggleTrigger: 0
    property string panelToggleName: ""
    property string panelToggleMode: ""
    onPanelToggleTriggerChanged: {
        if (panelToggleName === "calendar") calendarWindow.toggle();
        else if (panelToggleName === "weather") {
            if (panelToggleMode === "edit") weatherWindow.toggleEdit();
            else weatherWindow.toggle();
        }
        else if (panelToggleName === "clockSettings") clockSettingsWindow.toggle();
        else if (panelToggleName) sharedDropdown.togglePanel(panelToggleName);
    }

    function dismissPopups() {
        sharedDropdown.closePanel();
        calendarWindow.close();
        weatherWindow.close();
        clockSettingsWindow.close();
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
        Item {
            id: barRect
            x: Theme.barMargin + 1
            y: Theme.barMargin
            width: parent.width - (Theme.barMargin + 1) * 2
            height: Theme.barHeight


            readonly property real _glassAlpha: 0.88
            readonly property color _bgColor: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, _glassAlpha)

            // ── Left segment ────────────────────────────
            Item {
                id: leftSection
                anchors.left: parent.left
                height: parent.height
                width: Theme.barSideWidth

                Shape {
                    id: leftBg
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: barRect._bgColor
                        strokeColor: "transparent"
                        startX: 0; startY: 0
                        PathLine { x: leftSection.width; y: 0 }
                        PathLine { x: leftSection.width - Theme.barDiagSlant; y: leftSection.height }
                        PathLine { x: 0; y: leftSection.height }
                        PathLine { x: 0; y: 0 }
                    }
                }
                BarBorder {
                    anchors.fill: parent
                    pts: [[0,0], [width,0], [width-Theme.barDiagSlant,height], [0,height]]
                }

                // Launcher + workspaces — locked to left
                RowLayout {
                    id: leftContent
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.itemSpacing
                    spacing: 0

                    IconButton {
                        icon: Theme.iconSearch
                        Layout.alignment: Qt.AlignVCenter
                        Layout.rightMargin: Theme.spacingMedium
                        onClicked: root.launcherRequested()
                    }

                    Workspaces {
                        Layout.alignment: Qt.AlignVCenter
                        screenName: root.screenName
                    }
                }

                // Active window — after launcher/workspaces, left-aligned
                ActiveWindow {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: leftContent.right
                    anchors.leftMargin: Theme.itemSpacing
                    width: Math.min(implicitWidth, parent.width - leftContent.width - Theme.barDiagSlant - Theme.itemSpacing * 3)
                }
            }

            // ── Center segment ──────────────────────────
            Item {
                id: centerSection
                anchors.horizontalCenter: parent.horizontalCenter
                height: parent.height
                width: Math.max(centerContent.implicitWidth + Theme.barDiagSlant * 2 + Theme.barSegmentPadding, Theme.minCenterWidth)


                Shape {
                    id: centerBg
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: barRect._bgColor
                        strokeColor: "transparent"
                        // Trapezoid — narrow top, wide bottom: /----\
                        startX: Theme.barDiagSlant; startY: 0
                        PathLine { x: centerSection.width - Theme.barDiagSlant; y: 0 }
                        PathLine { x: centerSection.width; y: centerSection.height }
                        PathLine { x: 0; y: centerSection.height }
                        PathLine { x: Theme.barDiagSlant; y: 0 }
                    }
                }
                BarBorder {
                    anchors.fill: parent
                    pts: [[Theme.barDiagSlant,0], [width-Theme.barDiagSlant,0], [width,height], [0,height]]
                }

                // Center content: recording dot | clock | separator | weather
                Row {
                    id: centerContent
                    anchors.centerIn: parent
                    spacing: Theme.spacingMedium

                    // Recording indicator — pulsing red dot before clock
                    Rectangle {
                        visible: root.isRecording
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8; height: 8; radius: Theme.radiusTiny
                        color: Theme.red

                        SequentialAnimation on opacity {
                            running: root.isRecording
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: Theme.animLockFade }
                            NumberAnimation { to: 1.0; duration: Theme.animLockFade }
                        }
                    }

                    Clock {
                        id: clock
                        anchors.verticalCenter: parent.verticalCenter
                        popupVisible: calendarWindow.isOpen || clockSettingsWindow.isOpen
                        onTogglePopup: {
                            clockSettingsWindow.close();
                            calendarWindow.toggle();
                        }
                        onToggleConfigPopup: {
                            calendarWindow.close();
                            clockSettingsWindow.toggle();
                        }
                        onDismissPopup: {
                            calendarWindow.close();
                            clockSettingsWindow.close();
                        }
                    }

                    // Separator between clock and weather
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 14
                        color: Theme.outlineVariant
                    }

                    Weather {
                        id: weather
                        anchors.verticalCenter: parent.verticalCenter
                        popupVisible: weatherWindow.isOpen
                        onTogglePopup: weatherWindow.toggle()
                        onToggleEditPopup: weatherWindow.toggleEdit()
                        onDismissPopup: weatherWindow.close()
                    }
                }

            }

            // ── Right segment ───────────────────────────
            Item {
                id: rightSection
                anchors.right: parent.right
                height: parent.height
                width: Theme.barSideWidth

                Shape {
                    id: rightBg
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: barRect._bgColor
                        strokeColor: "transparent"
                        startX: 0; startY: 0
                        PathLine { x: rightSection.width; y: 0 }
                        PathLine { x: rightSection.width; y: rightSection.height }
                        PathLine { x: Theme.barDiagSlant; y: rightSection.height }
                        PathLine { x: 0; y: 0 }
                    }
                }
                BarBorder {
                    anchors.fill: parent
                    pts: [[0,0], [width,0], [width,height], [Theme.barDiagSlant,height]]
                }

                // ── Tray-specific state ───────────────────
                property var activeTrayItem: null

                function showTrayDropdown(trayItem) {
                    if (sharedDropdown.activePanel === "tray" && activeTrayItem === trayItem) {
                        sharedDropdown.closePanel();
                        return;
                    }
                    sharedDropdown.close();
                    activeTrayItem = trayItem;
                    sharedDropdown.activePanel = "tray";
                    sharedDropdown.anchor.item = rightSection;
                    sharedDropdown.anchor.rect.x = sharedDropdown.anchorX;
                    sharedDropdown.anchor.rect.y = rightSection.height;
                    trayOpenDelay.restart();
                }

                Timer {
                    id: trayOpenDelay
                    interval: Theme.menuRebuildDelay
                    onTriggered: sharedDropdown.open()
                }

                // Media zone — left side of right segment, clipped to available space
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.barDiagSlant + Theme.itemSpacing
                    anchors.right: rightContent.left
                    anchors.rightMargin: Theme.itemSpacing
                    implicitHeight: media.implicitHeight
                    clip: true

                    Media {
                        id: media
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, parent.width)
                        onTogglePopup: sharedDropdown.togglePanel("media")
                        onDismissPopup: sharedDropdown.closePanel()
                        popupVisible: sharedDropdown.activePanel === "media"
                    }
                }

                // System tray zone — locked to right side
                RowLayout {
                    id: rightContent
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.itemSpacing
                    spacing: Theme.itemSpacing

                    SysTray {
                        id: sysTray
                        Layout.alignment: Qt.AlignVCenter
                        menuVisible: sharedDropdown.activePanel === "tray"
                        onShowTrayMenu: item => rightSection.showTrayDropdown(item)
                    }

                    // ── System capsule ─────────────────────
                    Item {
                        id: capsule
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: capsuleRow.implicitWidth + 16
                        implicitHeight: Theme.barHeight - 10

                        readonly property bool capsuleActive:
                            sharedDropdown.activePanel === "volume"
                            || sharedDropdown.activePanel === "notifications"

                        // Capsule background
                        Rectangle {
                            anchors.fill: parent
                            radius: (Theme.barHeight - 10) / 2
                            color: capsule.capsuleActive ? Theme.bgHover : "transparent"
                            border.width: capsule.capsuleActive ? 1 : 0
                            border.color: Theme.outlineVariant

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        }

                        RowLayout {
                            id: capsuleRow
                            anchors.centerIn: parent
                            spacing: Theme.spacingMedium

                            // WiFi
                            CapsuleItem {
                                id: wifiCapsule
                                icon: Networking.wifiEnabled ? Theme.iconWifi : Theme.iconWifiOff
                                label: root._wifiConnected ? root._connectedNetwork.name : ""
                                alert: !Networking.wifiEnabled
                                connected: root._wifiConnected
                                onClicked: event => {
                                    if (event.button === Qt.MiddleButton)
                                        Networking.wifiEnabled = !Networking.wifiEnabled;
                                    else
                                        root.wifiRequested();
                                }

                                ThemedTooltip {
                                    showWhen: wifiCapsule.hovered
                                    text: {
                                        if (!Networking.wifiEnabled) return "WiFi Off";
                                        if (!root._wifiConnected) return "WiFi On — Not connected";
                                        const net = root._connectedNetwork;
                                        return `Connected to ${net.name}\nSignal: ${Math.round(net.signalStrength * 100)}%`;
                                    }
                                }
                            }

                            // Bluetooth
                            CapsuleItem {
                                id: btCapsule
                                icon: root._btAdapter?.enabled ? Theme.iconBluetooth : Theme.iconBluetoothOff
                                label: root._btConnected ? (root._connectedBtDevice.name || "") : ""
                                alert: !(root._btAdapter?.enabled ?? false)
                                connected: root._btConnected
                                onClicked: event => {
                                    if (event.button === Qt.MiddleButton && root._btAdapter)
                                        root._btAdapter.enabled = !root._btAdapter.enabled;
                                    else
                                        root.bluetoothRequested();
                                }

                                ThemedTooltip {
                                    showWhen: btCapsule.hovered
                                    text: {
                                        if (!(root._btAdapter?.enabled ?? false)) return "Bluetooth Off";
                                        if (!root._btConnected) return "Bluetooth On — No device";
                                        const dev = root._connectedBtDevice;
                                        let t = `Connected to ${dev.name || "Unknown"}`;
                                        if (dev.batteryAvailable) t += `\nBattery: ${Math.round(dev.battery * 100)}%`;
                                        return t;
                                    }
                                }
                            }

                            // Volume
                            CapsuleItem {
                                icon: Theme.volumeIcon(volume.rawVolume, volume.muted)
                                label: volume.volume + "%"
                                alert: volume.muted
                                active: sharedDropdown.activePanel === "volume"
                                onClicked: event => {
                                    if (event.button === Qt.MiddleButton)
                                        volume.toggleMute();
                                    else
                                        sharedDropdown.togglePanel("volume");
                                }
                                onWheel: event => {
                                    const step = Theme.volumeStep;
                                    if (event.angleDelta.y > 0)
                                        volume.setVolume(volume.rawVolume + step);
                                    else
                                        volume.setVolume(volume.rawVolume - step);
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
                                ActiveUnderline { visible: sharedDropdown.activePanel === "notifications" }

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
                                        color: Theme.accentFg
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
                                            sharedDropdown.togglePanel("notifications");
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Shared dropdown (all right-segment panels) ───
                AnimatedPopup {
                    id: sharedDropdown

                    autoPosition: false
                    anchorSection: rightSection
                    anchorX: Theme.barDiagSlant
                    implicitWidth: rightSection.width - Theme.barDiagSlant
                    anchor.adjustment: PopupAdjustment.None

                    fullHeight: {
                        switch (sharedDropdown.activePanel) {
                        case "volume": return volumeContent.implicitHeight + Theme.popupPadding * 2;
                        case "notifications": return notifContent.fullHeight;
                        case "media": return mediaContent.implicitHeight + Theme.popupPadding * 2;
                        case "tray": return Math.min(Theme.trayMenuMaxHeight, trayMenuColumn.implicitHeight + Theme.trayMenuPadding);
                        default: return 100;
                        }
                    }

                    onVisibleChanged: {
                        if (!visible) {
                            sharedDropdown.activePanel = "";
                            rightSection.activeTrayItem = null;
                            traySubMenu.visible = false;
                        }
                    }

                    // ── Volume section ────────────────────
                    ColumnLayout {
                        id: volumeContent
                        visible: sharedDropdown.activePanel === "volume"
                        enabled: visible
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.popupPadding
                        spacing: Theme.spacingTiny

                        VolumeSlider {
                            volumeSource: volume
                            Layout.fillWidth: true
                            Layout.bottomMargin: 2
                        }

                        Separator { visible: appVolume.hasStreams }

                        AppVolume {
                            id: appVolume
                            Layout.fillWidth: true
                        }
                    }

                    // ── Notifications section ─────────────
                    NotificationHistory {
                        id: notifContent
                        visible: sharedDropdown.activePanel === "notifications"
                        historyModel: root.notifHistoryModel
                        onRemoveFromHistory: nid => root.notifRemoved(nid)
                        onClearAllHistory: root.notifCleared()
                        onVisibleChanged: {
                            if (visible) root.notifPanelOpened();
                        }
                    }

                    // ── Media section ─────────────────────
                    ColumnLayout {
                        id: mediaContent
                        visible: sharedDropdown.activePanel === "media"
                        enabled: visible
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: Theme.popupPadding
                        width: Math.min(parent.width - Theme.popupPadding * 2, 280)
                        spacing: Theme.spacingMedium

                        property real currentPos: media.player ? media.player.position : 0
                        property real trackLen: media.player ? media.player.length : 0

                        FrameAnimation {
                            running: media.isPlaying && sharedDropdown.activePanel === "media"
                            onTriggered: {
                                if (media.player && !seekSlider.dragging)
                                    media.player.positionChanged();
                            }
                        }

                        Connections {
                            target: media.player
                            enabled: sharedDropdown.activePanel === "media"
                            function onPositionChanged() {
                                if (!seekSlider.dragging)
                                    mediaContent.currentPos = media.player ? media.player.position : 0;
                            }
                            function onLengthChanged() {
                                mediaContent.trackLen = media.player ? media.player.length : 0;
                            }
                        }

                        // Album art
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 160
                            Layout.preferredHeight: 160
                            radius: Theme.radiusMedium
                            color: Theme.bgHover
                            clip: true
                            layer.enabled: true

                            OptImage {
                                id: albumArt
                                anchors.fill: parent
                                source: media.player && media.player.trackArtUrl ? media.player.trackArtUrl : ""
                                visible: status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !albumArt.visible
                                text: Theme.iconPlay
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.fontSizeHero
                                color: Theme.fgDim
                                opacity: Theme.opacityDim
                            }
                        }

                        // Track title
                        Text {
                            Layout.fillWidth: true
                            text: media.title || "Unknown Title"
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }

                        // Artist
                        Text {
                            Layout.fillWidth: true
                            Layout.topMargin: -6
                            text: media.artist || "Unknown Artist"
                            color: Theme.fgDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }

                        // Album
                        Text {
                            Layout.fillWidth: true
                            Layout.topMargin: -6
                            visible: media.player && media.player.trackAlbum !== ""
                            text: media.player ? (media.player.trackAlbum || "") : ""
                            color: Theme.fgDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.italic: true
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            opacity: Theme.opacityBody
                        }

                        // Seek bar
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingTiny

                            SliderTrack {
                                id: seekSlider
                                Layout.fillWidth: true
                                visible: !media.isLive
                                value: mediaContent.trackLen > 0
                                    ? Math.max(0, Math.min(1, mediaContent.currentPos / mediaContent.trackLen)) : 0
                                accentColor: Theme.accent
                                trackHeight: 4
                                knobSize: 12
                                step: Theme.volumeStep
                                onMoved: function(newValue) {
                                    if (media.player && media.player.canSeek && mediaContent.trackLen > 0) {
                                        media.player.position = newValue * mediaContent.trackLen;
                                        mediaContent.currentPos = newValue * mediaContent.trackLen;
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    visible: !media.isLive
                                    text: media.formatTime(mediaContent.currentPos)
                                    color: Theme.fgDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeTiny
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    visible: media.isLive
                                    text: "LIVE"
                                    color: Theme.red
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeTiny
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Item { Layout.fillWidth: true; visible: media.isLive }
                                Text {
                                    visible: !media.isLive
                                    text: media.formatTime(mediaContent.trackLen)
                                    color: Theme.fgDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeTiny
                                }
                            }
                        }

                        // Transport controls
                        MediaControls {
                            Layout.alignment: Qt.AlignHCenter
                            player: media.player
                            spacing: 20
                            playSize: Theme.iconSize + 4
                        }
                    }

                    // ── Tray menu section ─────────────────
                    Item {
                        id: trayContent
                        visible: sharedDropdown.activePanel === "tray"
                        enabled: visible
                        anchors.fill: parent

                        QsMenuOpener {
                            id: trayOpener
                            menu: rightSection.activeTrayItem ? rightSection.activeTrayItem.menu : null
                        }

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 6
                            contentHeight: trayMenuColumn.implicitHeight
                            clip: true

                            ColumnLayout {
                                id: trayMenuColumn
                                width: parent.width
                                spacing: 0

                                Repeater {
                                    model: trayOpener.children ? [...trayOpener.children.values] : []

                                    MenuItem {
                                        id: trayEntry
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: implicitHeight

                                        onTriggered: {
                                            if (!modelData) return;
                                            if (modelData.hasChildren) {
                                                traySubMenu.menuSource = modelData;
                                                traySubMenu.anchorItem = trayEntry;
                                                traySubMenu.visible = !traySubMenu.visible;
                                            } else {
                                                modelData.triggered();
                                                sharedDropdown.closePanel();
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Submenu popup
                        PopupWindow {
                            id: traySubMenu
                            property var menuSource: null
                            property var anchorItem: null

                            visible: false
                            color: "transparent"
                            implicitWidth: 200
                            implicitHeight: Math.min(Theme.trayMenuMaxHeight, subColumn.implicitHeight + Theme.trayMenuPadding)

                            anchor.item: anchorItem
                            anchor.rect.x: anchorItem ? anchorItem.width + 4 : 0
                            anchor.rect.y: 0

                            QsMenuOpener {
                                id: subOpener
                                menu: traySubMenu.menuSource
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radiusMedium
                                color: Theme.bgSolid
                                border.width: 1
                                border.color: Theme.border

                                Flickable {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    contentHeight: subColumn.implicitHeight
                                    clip: true

                                    ColumnLayout {
                                        id: subColumn
                                        width: parent.width
                                        spacing: 0

                                        Repeater {
                                            model: subOpener.children ? [...subOpener.children.values] : []

                                            MenuItem {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: implicitHeight

                                                onTriggered: {
                                                    if (!modelData) return;
                                                    modelData.triggered();
                                                    traySubMenu.visible = false;
                                                    sharedDropdown.closePanel();
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Calendar dropdown — shares BarPopupWindow chrome with weather.
    // Width matches the center trapezoid's wide bottom edge so the
    // dropdown visually continues the bar below.
    CalendarWindow {
        id: calendarWindow
        screen: root.screen
        currentDate: clock.currentDate
        cardWidth: centerSection.width
    }

    // Weather dropdown — its own layer shell window so it can receive
    // keyboard focus for the search field without affecting the bar.
    WeatherWindow {
        id: weatherWindow
        screen: root.screen
        weather: weather
        cardWidth: centerSection.width
    }

    ClockSettingsWindow {
        id: clockSettingsWindow
        screen: root.screen
        cardWidth: centerSection.width
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

    // ── WiFi state ──
    readonly property var _wifiDevice: {
        const devs = Networking.devices?.values ?? [];
        for (let i = 0; i < devs.length; i++) {
            if (devs[i].type === DeviceType.Wifi) return devs[i];
        }
        return null;
    }
    readonly property var _connectedNetwork: {
        const nets = _wifiDevice?.networks?.values ?? [];
        for (let i = 0; i < nets.length; i++) {
            if (nets[i].connected) return nets[i];
        }
        return null;
    }
    readonly property bool _wifiConnected: _connectedNetwork !== null

    // ── Bluetooth state ──
    readonly property var _btAdapter: Bluetooth.defaultAdapter
    readonly property var _connectedBtDevice: {
        const devs = _btAdapter?.devices?.values ?? [];
        for (let i = 0; i < devs.length; i++) {
            if (devs[i].connected) return devs[i];
        }
        return null;
    }
    readonly property bool _btConnected: _connectedBtDevice !== null
}
