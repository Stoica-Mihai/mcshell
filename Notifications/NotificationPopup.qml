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
        // Each entry: see _buildEntry (full shape shared with _historyModel).
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

    // Index of the entry whose notifId matches nid, or -1.
    function _indexById(model, nid) {
        for (let i = 0; i < model.count; i++)
            if (model.get(i).notifId === nid) return i;
        return -1;
    }

    // Build the full entry object shared by the popup and history models.
    function _buildEntry(notification, nid, appIconUrl, imageUrl, timeout) {
        return {
            notifId: nid,
            appName: notification.appName || "",
            summary: notification.summary || "",
            body:    notification.body    || "",
            appIconUrl: appIconUrl,
            imageUrl:   imageUrl,
            urgency: notification.urgency < 0 || notification.urgency > 2
                     ? 1 : notification.urgency,
            timeout: timeout,
            hasActions: notification.actions && notification.actions.length > 0,
            hasInlineReply: !!notification.hasInlineReply,
            timestamp: new Date().toLocaleString(Qt.locale(), "hh:mm AP"),
            epochMs: Date.now()
        };
    }

    // ── Notification history (persistent across dismissals) ──
    property alias historyModel: _historyModel
    ListModel {
        id: _historyModel
        // Same full entry shape as notifModel (see _buildEntry), plus timestamp/epochMs.
    }

    // Remove the history entry at index i, dropping its retained ref too and
    // keeping unreadCount from exceeding the surviving entry count.
    function _removeHistoryAt(i) {
        delete root._notifRefs[_historyModel.get(i).notifId];
        _historyModel.remove(i);
        if (unreadCount > _historyModel.count) unreadCount = _historyModel.count;
    }

    function removeHistoryById(nid: string) {
        const i = _indexById(_historyModel, nid);
        if (i >= 0) _removeHistoryAt(i);
    }

    function clearHistory() {
        for (let i = 0; i < _historyModel.count; i++)
            delete root._notifRefs[_historyModel.get(i).notifId];
        _historyModel.clear();
    }

    // ── Auto-clean (event-driven, no polling) ──────────────
    onVisibleChanged: _scheduleClean()  // re-evaluate on reload
    Connections { target: UserSettings; function onNotifAutoCleanChanged() { root._scheduleClean(); } }

    Timer {
        id: _cleanTimer
        onTriggered: root._cleanExpired()
    }

    function _scheduleClean() {
        const threshold = UserSettings.notifAutoCleanMs(UserSettings.notifAutoClean);
        if (threshold <= 0 || _historyModel.count === 0) { _cleanTimer.stop(); return; }
        // Oldest entry is last in the model (newest-first order)
        const oldestMs = _historyModel.get(_historyModel.count - 1).epochMs;
        const expiresIn = (oldestMs + threshold) - Date.now();
        if (expiresIn <= 0) { _cleanExpired(); return; }
        _cleanTimer.interval = expiresIn;
        _cleanTimer.restart();
    }

    function _cleanExpired() {
        const threshold = UserSettings.notifAutoCleanMs(UserSettings.notifAutoClean);
        if (threshold <= 0) return;
        const now = Date.now();
        for (let i = _historyModel.count - 1; i >= 0; i--) {
            if (now - _historyModel.get(i).epochMs >= threshold)
                _removeHistoryAt(i);
        }
        _scheduleClean();
    }

    // ── Notification server (DBus daemon) ─────────────────
    NotificationServer {
        id: server
        keepOnReload: true
        imageSupported: true
        actionsSupported: true
        inlineReplySupported: true
        bodyHyperlinksSupported: false

        onNotification: notification => {
            // Header app icon — small icon for the notification source
            const appIconUrl = (notification.appIcon && notification.appIcon.toString() !== "")
                ? notification.appIcon.toString() : "";
            // Body image — large preview, only when the notification supplies one
            const imageUrl = (notification.image && notification.image.toString() !== "")
                ? notification.image.toString() : "";

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

            const entry = root._buildEntry(notification, nid, appIconUrl, imageUrl, timeout);

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

            // Always append to history (same full entry; extra roles are harmless)
            _historyModel.insert(0, entry);

            // Cap history (drops the evicted entries' retained refs too)
            while (_historyModel.count > root.maxHistory)
                _removeHistoryAt(_historyModel.count - 1);

            root._scheduleClean();

            // Cap visible popups
            while (notifModel.count > root.maxPopups)
                notifModel.remove(notifModel.count - 1);
        }
    }

    // ── Remove helper ─────────────────────────────────────
    function removeById(nid, userDismissed) {
        const i = _indexById(notifModel, nid);
        if (i < 0) return;
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

            // Buffer must exceed the maximum |bg.skewPx| of any card
            // (= |skew| * tallestCard / 2). With skew=-0.10 and ~400px cards
            // the slant reaches 20px, so 24px each side is comfortable.
            implicitWidth: root.popupWidth + 48
            implicitHeight: Math.max(1, stack.implicitHeight + 8)

            // Click-through: make the window itself transparent to input,
            // only the notification cards receive events.
            mask: Region {
                item: stack
            }

            // No BackgroundEffect.blurRegion: notification cards are opaque
            // so blur underneath would be invisible. Wayland blur regions
            // are axis-aligned rectangles, which would leak a vertical edge
            // through any translucent slanted card.

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
                    id: notifRepeater
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
