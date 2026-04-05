import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import qs.Config
import qs.Widgets
import qs.NotificationHistory

Scope {
    id: root

    property string screenName: ""
    property var screen: null
    property bool hasPopup: rightSection.activeDropdown !== "" || centerSection.activeDropdown !== ""

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
        if (panelToggleName === "calendar") centerSection.toggleDropdown("calendar");
        else if (panelToggleName) rightSection.toggleDropdown(panelToggleName);
    }

    function dismissPopups() {
        rightSection.closeDropdown();
        centerSection.closeDropdown();
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

            // Repaint all canvases when theme changes
            Connections {
                target: Theme
                function onBgSolidChanged() { leftBg.requestPaint(); centerBg.requestPaint(); rightBg.requestPaint(); }
                function onAccentChanged() { leftPulse.requestPaint(); centerPulse.requestPaint(); rightPulse.requestPaint(); }
            }

            // ── Animated bar border ─────────────────────
            property real _pulseTime: 0
            readonly property bool _borderActive: UserSettings.barBorderStyle !== "none"
            readonly property real _glassAlpha: 0.88

            Timer {
                interval: 32
                running: barRect._borderActive
                repeat: true
                onTriggered: {
                    barRect._pulseTime += interval;
                    leftPulse.requestPaint();
                    centerPulse.requestPaint();
                    rightPulse.requestPaint();
                }
            }

            // ── Shared drawing helpers ──────────────────
            // Trace the polygon path on ctx (no stroke/fill — caller finishes)
            function _tracePath(ctx, pts) {
                ctx.beginPath();
                ctx.moveTo(pts[0][0], pts[0][1]);
                for (var i = 1; i < pts.length; i++) ctx.lineTo(pts[i][0], pts[i][1]);
                ctx.closePath();
            }

            // Segment lengths + total perimeter from vertex array
            function _segLens(pts) {
                var lens = [], total = 0;
                for (var i = 0; i < pts.length; i++) {
                    var nx = (i + 1) % pts.length;
                    var dx = pts[nx][0] - pts[i][0], dy = pts[nx][1] - pts[i][1];
                    var l = Math.sqrt(dx * dx + dy * dy);
                    lens.push(l);
                    total += l;
                }
                return { lens: lens, total: total };
            }

            // Point at distance along perimeter
            function _pointAt(pts, perim, dist) {
                var r = dist % perim.total;
                if (r < 0) r += perim.total;
                for (var j = 0; j < perim.lens.length; j++) {
                    if (r <= perim.lens[j]) {
                        var t = r / perim.lens[j];
                        var nx = (j + 1) % pts.length;
                        return [pts[j][0] + (pts[nx][0] - pts[j][0]) * t,
                                pts[j][1] + (pts[nx][1] - pts[j][1]) * t];
                    }
                    r -= perim.lens[j];
                }
                return pts[0];
            }

            // Draw filled parallelogram background
            function _drawSegmentBg(ctx, w, h, pts) {
                ctx.clearRect(0, 0, w, h);
                barRect._tracePath(ctx, pts);
                ctx.fillStyle = Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, barRect._glassAlpha);
                ctx.fill();
            }

            // Pluggable border styles — each takes (ctx, w, h, pts, time)
            readonly property var _barBorderStyles: ({
                "pulse": function(ctx, w, h, pts, time) {
                    var perim = barRect._segLens(pts);

                    // Dim base border
                    barRect._tracePath(ctx, pts);
                    ctx.strokeStyle = Theme.accent;
                    ctx.lineWidth = 1;
                    ctx.globalAlpha = 0.15;
                    ctx.stroke();

                    // Flowing bright pulse
                    var pulsePos = (time * 0.00015 * perim.total) % perim.total;
                    var pulseLen = perim.total * 0.25;
                    var steps = 30;
                    ctx.lineWidth = 2;
                    ctx.lineCap = "round";
                    for (var s = 0; s < steps; s++) {
                        var d1 = pulsePos + (s / steps) * pulseLen;
                        var d2 = pulsePos + ((s + 1) / steps) * pulseLen;
                        var p1 = barRect._pointAt(pts, perim, d1);
                        var p2 = barRect._pointAt(pts, perim, d2);
                        ctx.globalAlpha = (1 - s / steps) * 0.7;
                        ctx.beginPath();
                        ctx.moveTo(p1[0], p1[1]);
                        ctx.lineTo(p2[0], p2[1]);
                        ctx.stroke();
                    }
                },

                "breathe": function(ctx, w, h, pts, time) {
                    barRect._tracePath(ctx, pts);
                    ctx.strokeStyle = Theme.accent;
                    ctx.lineWidth = 1.5;
                    ctx.globalAlpha = 0.25 + 0.55 * (0.5 + 0.5 * Math.sin(time * 0.002));
                    ctx.stroke();
                },

                "dashes": function(ctx, w, h, pts, time) {
                    barRect._tracePath(ctx, pts);
                    ctx.strokeStyle = Theme.accent;
                    ctx.lineWidth = 1.5;
                    ctx.globalAlpha = 0.7;
                    ctx.setLineDash([8, 12]);
                    ctx.lineDashOffset = -time * 0.03;
                    ctx.stroke();
                    ctx.setLineDash([]);
                },

                "none": function() {}
            })

            function _drawBarBorder(ctx, w, h, pts, time) {
                ctx.clearRect(0, 0, w, h);
                ctx.globalAlpha = 1;
                var fn = _barBorderStyles[UserSettings.barBorderStyle] || _barBorderStyles["pulse"];
                fn(ctx, w, h, pts, time);
                ctx.globalAlpha = 1;
            }

            // ── Left segment ────────────────────────────
            Item {
                id: leftSection
                anchors.left: parent.left
                height: parent.height
                width: rightSection.sectionMaxWidth

                Canvas {
                    id: leftBg
                    anchors.fill: parent
                    onPaint: barRect._drawSegmentBg(getContext("2d"), width, height,
                        [[0,0], [width,0], [width-Theme.barDiagSlant,height], [0,height]])
                }
                Canvas {
                    id: leftPulse
                    anchors.fill: parent
                    visible: barRect._borderActive
                    onPaint: barRect._drawBarBorder(getContext("2d"), width, height,
                        [[0,0], [width,0], [width-Theme.barDiagSlant,height], [0,height]],
                        barRect._pulseTime)
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
                        Layout.rightMargin: 10
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
                width: Math.max(clock.implicitWidth + Theme.barDiagSlant * 2 + 24, 280)

                // ── Shared dropdown state ─────────────────
                property string activeDropdown: ""  // "calendar"

                function toggleDropdown(name) {
                    if (activeDropdown === name) closeDropdown();
                    else openDropdown(name);
                }

                function openDropdown(name) {
                    centerDropdown.close();
                    activeDropdown = name;
                    if (name === "calendar") {
                        calendarContent.viewDate = new Date();
                        calendarContent.viewMode = "days";
                    }
                    centerDropdown.anchor.item = centerSection;
                    centerDropdown.anchor.rect.x = 0;
                    centerDropdown.anchor.rect.y = centerSection.height;
                    centerDropdown.open();
                }

                function closeDropdown() {
                    centerDropdown.close();
                }

                Canvas {
                    id: centerBg
                    anchors.fill: parent
                    onPaint: barRect._drawSegmentBg(getContext("2d"), width, height,
                        [[Theme.barDiagSlant,0], [width,0], [width-Theme.barDiagSlant,height], [0,height]])
                }
                Canvas {
                    id: centerPulse
                    anchors.fill: parent
                    visible: barRect._borderActive
                    onPaint: barRect._drawBarBorder(getContext("2d"), width, height,
                        [[Theme.barDiagSlant,0], [width,0], [width-Theme.barDiagSlant,height], [0,height]],
                        barRect._pulseTime)
                }

                Clock {
                    id: clock
                    anchors.centerIn: parent
                    popupVisible: centerSection.activeDropdown === "calendar"
                    onTogglePopup: centerSection.toggleDropdown("calendar")
                    onDismissPopup: centerSection.closeDropdown()
                }

                // Recording indicator — pulsing red dot left of clock
                Rectangle {
                    visible: root.isRecording
                    anchors.right: clock.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8; height: 8; radius: 4
                    color: Theme.red

                    SequentialAnimation on opacity {
                        running: root.isRecording
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: Theme.animLockFade }
                        NumberAnimation { to: 1.0; duration: Theme.animLockFade }
                    }
                }

                // ── Center shared dropdown ───────────────
                AnimatedPopup {
                    id: centerDropdown

                    autoPosition: false
                    implicitWidth: centerSection.width - Theme.barDiagSlant
                    anchor.adjustment: PopupAdjustment.None

                    fullHeight: calendarContent.fullHeight

                    onVisibleChanged: {
                        if (!visible) centerSection.activeDropdown = "";
                    }

                    CalendarPopup {
                        id: calendarContent
                        visible: centerSection.activeDropdown === "calendar"
                        currentDate: clock.currentDate
                    }
                }
            }

            // ── Right segment ───────────────────────────
            Item {
                id: rightSection
                anchors.right: parent.right
                height: parent.height
                property real sectionFullWidth: media.implicitWidth + rightContent.implicitWidth + Theme.barDiagSlant + Theme.itemSpacing * 3 + 12
                property real sectionMaxWidth: 0
                onSectionFullWidthChanged: sectionMaxWidth = Math.max(sectionMaxWidth, sectionFullWidth)
                width: sectionMaxWidth

                Canvas {
                    id: rightBg
                    anchors.fill: parent
                    onPaint: barRect._drawSegmentBg(getContext("2d"), width, height,
                        [[0,0], [width,0], [width,height], [Theme.barDiagSlant,height]])
                }
                Canvas {
                    id: rightPulse
                    anchors.fill: parent
                    visible: barRect._borderActive
                    onPaint: barRect._drawBarBorder(getContext("2d"), width, height,
                        [[0,0], [width,0], [width,height], [Theme.barDiagSlant,height]],
                        barRect._pulseTime)
                }

                // ── Shared dropdown state ─────────────────
                property string activeDropdown: ""  // "volume", "notifications", "media", "tray"
                property var activeTrayItem: null

                function toggleDropdown(name) {
                    if (activeDropdown === name) {
                        closeDropdown();
                    } else {
                        openDropdown(name);
                    }
                }

                function openDropdown(name) {
                    sharedDropdown.close();
                    activeDropdown = name;
                    sharedDropdown.anchor.item = rightSection;
                    sharedDropdown.anchor.rect.x = Theme.barDiagSlant;
                    sharedDropdown.anchor.rect.y = rightSection.height;
                    sharedDropdown.open();
                }

                function closeDropdown() {
                    sharedDropdown.close();
                }

                function showTrayDropdown(trayItem) {
                    if (activeDropdown === "tray" && activeTrayItem === trayItem) {
                        closeDropdown();
                        return;
                    }
                    sharedDropdown.close();
                    activeTrayItem = trayItem;
                    activeDropdown = "tray";
                    sharedDropdown.anchor.item = rightSection;
                    sharedDropdown.anchor.rect.x = Theme.barDiagSlant;
                    sharedDropdown.anchor.rect.y = rightSection.height;
                    trayOpenDelay.restart();
                }

                Timer {
                    id: trayOpenDelay
                    interval: 16
                    onTriggered: sharedDropdown.open()
                }

                // Media zone — left side of right segment
                Media {
                    id: media
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.barDiagSlant + Theme.itemSpacing
                    onTogglePopup: rightSection.toggleDropdown("media")
                    onDismissPopup: rightSection.closeDropdown()
                    popupVisible: rightSection.activeDropdown === "media"
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
                        menuVisible: rightSection.activeDropdown === "tray"
                        onShowTrayMenu: item => rightSection.showTrayDropdown(item)
                    }

                    // ── System capsule ─────────────────────
                    Item {
                        id: capsule
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: capsuleRow.implicitWidth + 16
                        implicitHeight: Theme.barHeight - 10

                        readonly property bool capsuleActive:
                            rightSection.activeDropdown === "volume"
                            || rightSection.activeDropdown === "notifications"

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

                            // Volume
                            CapsuleItem {
                                icon: Theme.volumeIcon(volume.rawVolume, volume.muted)
                                label: volume.volume + "%"
                                alert: volume.muted
                                active: rightSection.activeDropdown === "volume"
                                onClicked: event => {
                                    if (event.button === Qt.MiddleButton)
                                        volume.toggleMute();
                                    else
                                        rightSection.toggleDropdown("volume");
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
                                ActiveUnderline { visible: rightSection.activeDropdown === "notifications" }

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
                                            rightSection.toggleDropdown("notifications");
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
                    implicitWidth: rightSection.width - Theme.barDiagSlant
                    anchor.adjustment: PopupAdjustment.None

                    fullHeight: {
                        switch (rightSection.activeDropdown) {
                        case "volume": return volumeContent.implicitHeight + Theme.popupPadding * 2;
                        case "notifications": return notifContent.fullHeight;
                        case "media": return mediaContent.implicitHeight + Theme.popupPadding * 2;
                        case "tray": return Math.min(400, trayMenuColumn.implicitHeight + 12);
                        default: return 100;
                        }
                    }

                    onVisibleChanged: {
                        if (!visible) {
                            rightSection.activeDropdown = "";
                            rightSection.activeTrayItem = null;
                            traySubMenu.visible = false;
                        }
                    }

                    // ── Volume section ────────────────────
                    ColumnLayout {
                        id: volumeContent
                        visible: rightSection.activeDropdown === "volume"
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

                        Separator { visible: appVolume.hasStreams }

                        AppVolume {
                            id: appVolume
                            Layout.fillWidth: true
                        }
                    }

                    // ── Notifications section ─────────────
                    NotificationHistory {
                        id: notifContent
                        visible: rightSection.activeDropdown === "notifications"
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
                        visible: rightSection.activeDropdown === "media"
                        enabled: visible
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: Theme.popupPadding
                        width: Math.min(parent.width - Theme.popupPadding * 2, 280)
                        spacing: Theme.spacingMedium

                        property real currentPos: media.player ? media.player.position : 0
                        property real trackLen: media.player ? media.player.length : 0

                        FrameAnimation {
                            running: media.isPlaying && rightSection.activeDropdown === "media"
                            onTriggered: {
                                if (media.player && !seekSlider.dragging)
                                    media.player.positionChanged();
                            }
                        }

                        Connections {
                            target: media.player
                            enabled: rightSection.activeDropdown === "media"
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
                        visible: rightSection.activeDropdown === "tray"
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
                                                rightSection.closeDropdown();
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
                            implicitHeight: Math.min(400, subColumn.implicitHeight + 12)

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
                                                    rightSection.closeDropdown();
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
