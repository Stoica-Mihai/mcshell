import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs.Config

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
    readonly property int defaultTimeout: 5000   // ms
    readonly property int maxPopups: 5
    readonly property int topMargin: Theme.barHeight + Theme.barMargin * 2 + 8
    readonly property int rightMargin: Theme.barMargin + 4

    // ── Internal notification list model ──────────────────
    ListModel {
        id: notifModel
        // Each entry: { nid, appName, summary, body, iconUrl, urgency, timeout }
    }

    // ── Notification server (DBus daemon) ─────────────────
    NotificationServer {
        id: server
        keepOnReload: false
        imageSupported: true
        actionsSupported: false
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

            notifModel.insert(0, {
                nid: nid,
                appName: notification.appName || "",
                summary: notification.summary || "",
                body:    notification.body    || "",
                iconUrl: icon,
                urgency: notification.urgency < 0 || notification.urgency > 2
                         ? 1 : notification.urgency,
                timeout: timeout
            });

            // Cap visible popups
            while (notifModel.count > root.maxPopups)
                notifModel.remove(notifModel.count - 1);
        }
    }

    // ── Remove helper ─────────────────────────────────────
    function removeById(nid: string) {
        for (let i = 0; i < notifModel.count; i++) {
            if (notifModel.get(i).nid === nid) {
                notifModel.remove(i);
                return;
            }
        }
    }

    // ── One popup window per screen ───────────────────────
    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: popup

            required property var modelData
            screen: modelData

            // Layer-shell setup
            WlrLayershell.namespace: "mcshell-notifications"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            color: "transparent"

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

            // ── Notification stack ────────────────────────
            ColumnLayout {
                id: stack
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.topMargin: 4
                width: root.popupWidth
                spacing: 8

                Repeater {
                    model: notifModel

                    delegate: NotificationCard {
                        notifId: model.nid
                        appName: model.appName
                        summary: model.summary
                        body: model.body
                        iconUrl: model.iconUrl
                        urgency: model.urgency

                        Layout.fillWidth: true

                        // Auto-dismiss timer
                        Timer {
                            id: autoDismiss
                            interval: model.timeout
                            running: true
                            onTriggered: animateOut()
                        }

                        // Pause timer on hover
                        HoverHandler {
                            onHoveredChanged: {
                                if (hovered)
                                    autoDismiss.running = false;
                                else
                                    autoDismiss.restart();
                            }
                        }

                        onDismissed: nid => root.removeById(nid)
                    }
                }
            }
        }
    }
}
