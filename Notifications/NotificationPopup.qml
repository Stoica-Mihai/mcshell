import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs.Config
import qs.Core

// Notification popup module.
// Instantiates a NotificationServer (DBus notification daemon) and shows
// incoming notifications as stacked cards in the top-right corner.
//
// Usage from shell.qml:
//   import qs.Notifications
//   ShellRoot { NotificationPopup {} }

Item {
    id: root

    // ── Configuration ─────────────────────────────────────
    readonly property int popupWidth: 360
    readonly property int defaultTimeout: Theme.notifDefaultTimeout
    readonly property int maxPopups: 5
    readonly property int topMargin: Theme.barHeight + Theme.barMargin * 2 + 8
    readonly property int rightMargin: Theme.barMargin + 4
    readonly property int maxHistory: 50

    // ── Unread tracking ─────────────────────────────────
    property int unreadCount: 0

    function markAllRead() {
        // Dismiss all active popups — they're already in history
        while (notifModel.count > 0) {
            const nid = notifModel.get(0).notifId;
            const ref = _notifRefs[nid];
            if (ref) ref.expire();
            notifModel.remove(0);
        }
        unreadCount = 0;
    }

    // ── Internal notification list model ──────────────────
    ListModel {
        id: notifModel
        // Each entry: { notifId, appName, summary, body, iconUrl, urgency, timeout }
    }

    // ── Shared pause state (across all screens) ─────────
    property var pausedNotifs: ({})
    signal pauseStateChanged()

    function setPaused(nid, paused) {
        if (paused)
            pausedNotifs[nid] = true;
        else
            delete pausedNotifs[nid];
        pauseStateChanged();
    }

    function isPaused(nid) {
        return !!pausedNotifs[nid];
    }

    // ── Notification object references (for action invocation) ──
    property var _notifRefs: ({})

    function getNotifRef(nid) { return _notifRefs[nid] ?? null; }

    // ── Notification history (persistent across dismissals) ──
    property alias historyModel: _historyModel
    ListModel {
        id: _historyModel
        // Each entry: { nid, appName, summary, body, iconUrl, urgency, timestamp }
    }

    function removeHistoryById(nid: string) {
        for (let i = 0; i < _historyModel.count; i++) {
            if (_historyModel.get(i).notifId === nid) {
                _historyModel.remove(i);
                delete root._notifRefs[nid];
                return;
            }
        }
    }

    function clearHistory() {
        for (let i = 0; i < _historyModel.count; i++)
            delete root._notifRefs[_historyModel.get(i).notifId];
        _historyModel.clear();
    }

    // ── Auto-clean (event-driven, no polling) ──────────────
    readonly property var _autoCleanMs: ({
        "never": 0, "30m": 1800000, "1h": 3600000, "6h": 21600000, "24h": 86400000
    })
    onVisibleChanged: _scheduleClean()  // re-evaluate on reload
    Connections { target: UserSettings; function onNotifAutoCleanChanged() { root._scheduleClean(); } }

    Timer {
        id: _cleanTimer
        onTriggered: root._cleanExpired()
    }

    function _scheduleClean() {
        const threshold = _autoCleanMs[UserSettings.notifAutoClean] || 0;
        if (threshold <= 0 || _historyModel.count === 0) { _cleanTimer.stop(); return; }
        // Oldest entry is last in the model (newest-first order)
        const oldestMs = _historyModel.get(_historyModel.count - 1).epochMs;
        const expiresIn = (oldestMs + threshold) - Date.now();
        if (expiresIn <= 0) { _cleanExpired(); return; }
        _cleanTimer.interval = expiresIn;
        _cleanTimer.restart();
    }

    function _cleanExpired() {
        const threshold = _autoCleanMs[UserSettings.notifAutoClean] || 0;
        if (threshold <= 0) return;
        const now = Date.now();
        for (let i = _historyModel.count - 1; i >= 0; i--) {
            if (now - _historyModel.get(i).epochMs >= threshold) {
                delete root._notifRefs[_historyModel.get(i).notifId];
                _historyModel.remove(i);
            }
        }
        if (unreadCount > _historyModel.count)
            unreadCount = _historyModel.count;
        _scheduleClean();
    }

    // ── Notification server (DBus daemon) ─────────────────
    NotificationServer {
        id: server
        keepOnReload: false
        imageSupported: true
        actionsSupported: true
        inlineReplySupported: true
        bodyHyperlinksSupported: false

        onNotification: notification => {
            // Build icon URL: prefer image, then appIcon
            let icon = "";
            if (notification.image && notification.image.toString() !== "")
                icon = notification.image;
            else if (notification.appIcon && notification.appIcon.toString() !== "")
                icon = notification.appIcon;

            // Determine timeout
            let timeout = root.defaultTimeout;
            if (notification.expireTimeout > 0)
                timeout = notification.expireTimeout;

            // Generate a unique id for our internal tracking
            const nid = Date.now().toString(36) + Math.random().toString(36).substr(2, 5);

            // Track the notification so QuickShell doesn't garbage-collect it
            notification.tracked = true;

            // Store notification reference in a lookup map (ListModel can't hold QObjects)
            root._notifRefs[nid] = notification;

            const entry = {
                notifId: nid,
                appName: notification.appName || "",
                summary: notification.summary || "",
                body:    notification.body    || "",
                iconUrl: icon,
                urgency: notification.urgency < 0 || notification.urgency > 2
                         ? 1 : notification.urgency,
                timeout: timeout,
                hasActions: notification.actions && notification.actions.length > 0,
                hasInlineReply: !!notification.hasInlineReply
            };

            // Show popup only if DND is off
            if (!UserSettings.doNotDisturb) {
                // Deduplicate: silently dismiss existing popups from the same app
                // (they're already in history — keep refs alive for reply)
                for (let i = notifModel.count - 1; i >= 0; i--) {
                    if (notifModel.get(i).appName === entry.appName) {
                        unreadCount++;
                        notifModel.remove(i);
                    }
                }
                notifModel.insert(0, entry);
            }

            // Always append to history
            _historyModel.insert(0, {
                notifId: nid,
                appName: entry.appName,
                summary: entry.summary,
                body:    entry.body,
                iconUrl: icon,
                urgency: entry.urgency,
                hasInlineReply: entry.hasInlineReply,
                timestamp: new Date().toLocaleString(Qt.locale(), "hh:mm AP"),
                epochMs: Date.now()
            });

            // Cap history
            while (_historyModel.count > root.maxHistory)
                _historyModel.remove(_historyModel.count - 1);

            root._scheduleClean();

            // Cap visible popups
            while (notifModel.count > root.maxPopups)
                notifModel.remove(notifModel.count - 1);
        }
    }

    // ── Remove helper ─────────────────────────────────────
    function removeById(nid, userDismissed) {
        for (let i = 0; i < notifModel.count; i++) {
            if (notifModel.get(i).notifId === nid) {
                // Close the D-Bus notification so notify-send unblocks
                const ref = _notifRefs[nid];
                if (ref) {
                    try {
                        if (userDismissed) ref.dismiss();
                        else ref.expire();
                    } catch(e) {}
                }
                if (userDismissed) {
                    removeHistoryById(nid);
                } else {
                    unreadCount++;
                }
                notifModel.remove(i);
                return;
            }
        }
    }

    // ── One popup window per screen ───────────────────────
    Variants {
        model: Quickshell.screens

        delegate: OverlayWindow {
            id: popup
            namespace: Namespaces.notifications
            focusMode: WlrKeyboardFocus.OnDemand

            required property var modelData
            screen: modelData

            // Anchor top-right
            anchors {
                top: true
                right: true
            }

            margins {
                top: root.topMargin
                right: root.rightMargin
            }

            // Sizing
            implicitWidth: root.popupWidth + 16  // 8px padding each side
            implicitHeight: Math.max(1, stack.implicitHeight + 8)

            // Click-through: make the window itself transparent to input,
            // only the notification cards receive events.
            mask: Region {
                item: stack
            }

            // Background blur — bound to the stack bounding box, only when
            // there are actual cards (otherwise the empty stack produces a
            // phantom region that niri renders as a blurred rectangle).
            BackgroundEffect.blurRegion: UserSettings.blurEnabled && notifModel.count > 0
                ? stackBlurRegion : null
            Region { id: stackBlurRegion; item: stack }

            // ── Notification stack ────────────────────────
            ColumnLayout {
                id: stack
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingNormal
                anchors.topMargin: 4
                width: root.popupWidth
                spacing: Theme.spacingNormal

                Repeater {
                    model: notifModel

                    delegate: NotificationCard {
                        id: notifCard
                        // required properties auto-bind from ListModel roles:
                        // notifId, appName, summary, body, iconUrl, urgency, timeout, hasActions, hasInlineReply

                        Layout.fillWidth: true
                        getNotifRef: function() { return root.getNotifRef(notifCard.notifId); }

                        // Hover sets shared pause state — all screens react
                        HoverHandler {
                            onHoveredChanged: root.setPaused(notifCard.notifId, hovered)
                        }

                        // React to shared pause state
                        Connections {
                            target: root
                            function onPauseStateChanged() {
                                if (root.isPaused(notifCard.notifId) && !notifCard.countdownPaused)
                                    notifCard.pauseCountdown();
                                else if (!root.isPaused(notifCard.notifId) && notifCard.countdownPaused)
                                    notifCard.resumeCountdown();
                            }
                        }

                        onDismissed: nid => {
                            root.removeById(nid, notifCard._userDismissed);
                        }
                    }
                }
            }
        }
    }
}
