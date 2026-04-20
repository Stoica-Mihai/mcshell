import QtQuick
import QtQuick.Layouts
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
        || sysInfoSettingsWindow.isOpen

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
    // Dispatch table for bar-popup-window panels. Any panel name not in the
    // table falls through to the shared right-segment dropdown.
    readonly property var _barPanels: ({
        calendar: calendarWindow,
        weather: weatherWindow,
        clockSettings: clockSettingsWindow,
        sysInfoSettings: sysInfoSettingsWindow
    })
    onPanelToggleTriggerChanged: {
        if (!panelToggleName) return;
        const win = _barPanels[panelToggleName];
        if (!win) {
            sharedDropdown.togglePanel(panelToggleName);
            return;
        }
        if (panelToggleMode === "edit" && win.toggleEdit) win.toggleEdit();
        else win.toggle();
    }

    function dismissPopups() {
        sharedDropdown.closePanel();
        calendarWindow.close();
        weatherWindow.close();
        clockSettingsWindow.close();
        sysInfoSettingsWindow.close();
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

        // Prevent auto-lock during media playback.
        // IdleInhibitor requires idle-inhibit-unstable-v1 (not in stock quickshell).
        // Created dynamically to avoid hard dep on non-stock type.
        Component.onCompleted: {
            try {
                Qt.createQmlObject(
                    'import Quickshell; import Quickshell.Wayland;'
                    + ' IdleInhibitor { window: exclusionZone; enabled: root.mediaPlaying }',
                    exclusionZone, "IdleInhibitor");
            } catch (e) {}
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
            enabled: root.hasPopup
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
            readonly property color _bgColor: Theme.withAlpha(Theme.surfaceContainer, _glassAlpha)

            // ── Left segment ────────────────────────────
            Item {
                id: leftSection
                anchors.left: parent.left
                height: parent.height
                width: Theme.barSideWidth

                BarSegment {
                    anchors.fill: parent
                    fillColor: barRect._bgColor
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


                // Trapezoid — narrow top, wide bottom: /----\
                BarSegment {
                    anchors.fill: parent
                    fillColor: barRect._bgColor
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
                        width: Theme.indicatorDotSize
                        height: Theme.indicatorDotSize
                        radius: Theme.radiusTiny
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

                BarSegment {
                    anchors.fill: parent
                    fillColor: barRect._bgColor
                    pts: [[0,0], [width,0], [width,height], [Theme.barDiagSlant,height]]
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
                    spacing: Theme.spacingNormal

                    SysTray {
                        id: sysTray
                        Layout.alignment: Qt.AlignVCenter
                        menuVisible: sharedDropdown.activePanel === "tray"
                        expanded: sharedDropdown.activePanel === "trayicons"
                        onToggleExpand: sharedDropdown.togglePanel("trayicons")
                    }

                    // Separator between tray and capsule — matches barBorderStyle
                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 1
                        Layout.preferredHeight: capsule.implicitHeight
                        visible: sysTray.implicitWidth > 0
                        color: UserSettings.barBorderStyle === "gradient" ? "transparent" : Theme.accent
                        gradient: UserSettings.barBorderStyle === "gradient" ? _sepGrad : null

                        Gradient {
                            id: _sepGrad
                            GradientStop { position: 0.0; color: Theme.accent }
                            GradientStop { position: 0.5; color: Theme.secondary }
                            GradientStop { position: 1.0; color: Theme.tertiary }
                        }
                    }

                    // ── System capsule ─────────────────────
                    Item {
                        id: capsule
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: capsuleRow.implicitWidth + 10
                        implicitHeight: Theme.barHeight - 10

                        readonly property bool capsuleActive:
                            sharedDropdown.activePanel === "volume"
                            || sharedDropdown.activePanel === "notifications"
                            || sharedDropdown.activePanel === "sysinfo"

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
                                badge: root._connectedNetworks.length
                                alert: !Networking.wifiEnabled
                                enabled_: Networking.wifiEnabled && !root._wifiConnected
                                connected: root._wifiConnected
                                onClicked: event => {
                                    if (event.button === Qt.MiddleButton)
                                        Networking.wifiEnabled = !Networking.wifiEnabled;
                                    else
                                        root.wifiRequested();
                                }

                                ThemedTooltip {
                                    showWhen: wifiCapsule.hovered && root._wifiConnected
                                    text: {
                                        return root._connectedNetworks.map(n => {
                                            const signal = Math.round(n.signalStrength * 100);
                                            const sec = n.security === WifiSecurityType.Open ? "Open" : "Secured";
                                            return `${n.name}\n${signal}% signal · ${sec}`;
                                        }).join("\n\n");
                                    }
                                }
                            }

                            // Bluetooth
                            CapsuleItem {
                                id: btCapsule
                                icon: root._btAdapter?.enabled ? Theme.iconBluetooth : Theme.iconBluetoothOff
                                badge: root._connectedBtDevices.length
                                alert: !(root._btAdapter?.enabled ?? false)
                                enabled_: (root._btAdapter?.enabled ?? false) && !root._btConnected
                                connected: root._btConnected
                                onClicked: event => {
                                    if (event.button === Qt.MiddleButton && root._btAdapter)
                                        root._btAdapter.enabled = !root._btAdapter.enabled;
                                    else
                                        root.bluetoothRequested();
                                }

                                ThemedTooltip {
                                    showWhen: btCapsule.hovered && root._btConnected
                                    text: {
                                        const types = {
                                            "audio-headset": "Headset", "audio-headphones": "Headphones",
                                            "audio-card": "Speaker", "input-gaming": "Controller",
                                            "input-keyboard": "Keyboard", "input-mouse": "Mouse",
                                            "input-tablet": "Tablet", "phone": "Phone", "computer": "Computer"
                                        };
                                        return root._connectedBtDevices.map(d => {
                                            const name = d.name || d.deviceName || "Unknown";
                                            const type = types[d.icon] ?? "";
                                            let info = type;
                                            if (d.batteryAvailable)
                                                info += (info ? " · " : "") + Math.round(d.battery * 100) + "%";
                                            return info ? `${name}\n${info}` : name;
                                        }).join("\n\n");
                                    }
                                }
                            }

                            // Volume
                            VolumeWaveform {
                                rawVolume: volume.rawVolume
                                volume: volume.volume
                                muted: volume.muted
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
                            CapsuleItem {
                                icon: UserSettings.doNotDisturb ? Theme.iconDndOn : Theme.iconBell
                                alert: UserSettings.doNotDisturb
                                highlight: root.unreadNotifications > 0 && !UserSettings.doNotDisturb
                                badge: UserSettings.doNotDisturb ? 0 : root.unreadNotifications
                                badgeColor: Theme.yellow
                                active: sharedDropdown.activePanel === "notifications"
                                onClicked: event => {
                                    if (event.button === Qt.MiddleButton)
                                        UserSettings.doNotDisturb = !UserSettings.doNotDisturb;
                                    else
                                        sharedDropdown.togglePanel("notifications");
                                }
                            }

                            // System waveform
                            SysWaveform {
                                visible: UserSettings.sysInfoEnabled
                                active: sharedDropdown.activePanel === "sysinfo"
                                onClicked: {
                                    sysInfoSettingsWindow.close();
                                    sharedDropdown.togglePanel("sysinfo");
                                }
                                onToggleConfigPopup: {
                                    sharedDropdown.closePanel();
                                    sysInfoSettingsWindow.toggle();
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
                        case "sysinfo": return sysInfoContent.implicitHeight + Theme.popupPadding * 2;
                        case "trayicons": return trayIconsContent.implicitHeight + Theme.popupPadding * 2;
                        default: return 100;
                        }
                    }

                    onVisibleChanged: {
                        if (!visible) {
                            sharedDropdown.activePanel = "";
                            trayIconsContent.closeMenu();
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

                    // ── Tray icons section ────────────────
                    SysTrayPanel {
                        id: trayIconsContent
                        visible: sharedDropdown.activePanel === "trayicons"
                        enabled: visible
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.popupPadding
                    }

                    // ── SysInfo section ───────────────────
                    // Loader-gated so the sysinfo bindings don't churn
                    // on every SysInfo poll while the dropdown is closed.
                    Loader {
                        id: sysInfoContent
                        active: sharedDropdown.activePanel === "sysinfo"
                        visible: active
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.popupPadding
                        sourceComponent: SysInfoPanel {}
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

    SysInfoSettingsWindow {
        id: sysInfoSettingsWindow
        screen: root.screen
        cardWidth: rightSection.width - Theme.barDiagSlant
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
    readonly property var _connectedNetworks: {
        const nets = _wifiDevice?.networks?.values ?? [];
        const result = [];
        for (let i = 0; i < nets.length; i++) {
            if (nets[i].connected) result.push(nets[i]);
        }
        return result;
    }
    readonly property bool _wifiConnected: _connectedNetworks.length > 0

    // ── Bluetooth state ──
    readonly property var _btAdapter: Bluetooth.defaultAdapter
    readonly property var _connectedBtDevices: {
        const devs = _btAdapter?.devices?.values ?? [];
        const result = [];
        for (let i = 0; i < devs.length; i++) {
            if (devs[i].connected) result.push(devs[i]);
        }
        return result;
    }
    readonly property bool _btConnected: _connectedBtDevices.length > 0
}
