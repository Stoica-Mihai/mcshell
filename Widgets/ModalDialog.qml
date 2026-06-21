import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Core

// Shared modal-dialog scaffold for full-screen overlay dialogs (polkit auth,
// bluetooth pairing, etc.).
//
// Replicates per-screen via `Variants { model: Quickshell.screens }` so callers
// instantiate exactly one `ModalDialog` and get the full multi-monitor stack
// for free. Owns:
//   - the layer-shell OverlayWindow (fullscreen anchors, `active` gate)
//   - the BackgroundEffect blur region, gated on `active` to avoid the
//     phantom-blur-rect issue documented in CLAUDE.md (the layer-shell
//     surface stays alive across hide/show cycles)
//   - the click-blocking backdrop with `Theme.backdrop` and animSmooth fade
//   - the centred glass-bg dialog card with opacity + scale Behaviors
//   - escape-to-dismiss via a focus-capture Item, emitting `dismissed()`
//
// Content goes in `contentComponent` (a QML Component, not inline children).
// Each per-screen overlay instantiates the Component via a Loader, so IDs
// inside the content (text fields, Connections, etc.) resolve per-instance.
// This matches the existing dialogs' implicit behaviour: every monitor gets
// its own copy of the dialog body, every copy listens to the same external
// signal source (the polkit agent, the bluetooth pairing agent), and any
// single one accepting focus wins.
Item {
    id: root

    // Visibility gate. Drives blur, backdrop opacity, dialog opacity+scale,
    // OverlayWindow input mask, and keyboard focus capture.
    required property bool active

    // Card sizing. dialogHeight unset (0) means auto-size to content
    // (implicitHeight + 2×padding).
    property int dialogWidth: Theme.dialogWidth
    property int dialogHeight: 0

    // Card border colour — Polkit uses Theme.border, BT pair uses Theme.outlineVariant.
    property color borderColor: Theme.border

    // Layer-shell namespace (Namespaces.polkit, Namespaces.bluetoothPair, ...).
    property string namespace: Namespaces.root

    // Optional horizontal shake offset (used by Polkit for failed-auth feedback).
    // Applied as a Translate transform on the dialog card so the border shakes
    // with the content.
    property real shakeOffsetX: 0

    // Emitted when the user presses Escape while the dialog is active AND no
    // descendant in `contentComponent` consumed the event. Callers wire this
    // to their cancel path (polkit: cancelAuthenticationRequest, bt-pair:
    // reject()).
    signal dismissed()

    // Content Component. Instantiated once per screen via Loader. Children
    // reference the outer scope (the calling dialog's properties, singletons,
    // etc.) lexically as in any other Component. Callers typically root the
    // Component at a ColumnLayout sized to the dialog interior:
    //
    //     contentComponent: Component {
    //         ColumnLayout {
    //             anchors.fill: parent
    //             anchors.margins: Theme.dialogPadding
    //             ...
    //         }
    //     }
    property Component contentComponent

    Variants {
        model: Quickshell.screens

        OverlayWindow {
            id: overlay
            namespace: root.namespace
            active: root.active

            required property var modelData
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }

            // Blur region tracks the dialog card with its corner radius. Gated
            // on root.active so the surface, which stays alive across
            // activations, doesn't paint a phantom blur rect while idle.
            BackgroundEffect.blurRegion: UserSettings.blurEnabled && root.active
                ? dialogBlurRegion : null
            Region { id: dialogBlurRegion; item: dialog; radius: Theme.dialogRadius }

            // Backdrop dim
            Rectangle {
                anchors.fill: parent
                color: Theme.backdrop
                opacity: root.active ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.animSmooth } }

                // Block click-through; backdrop-click does NOT dismiss
                // (matches the existing dialogs — keyboard Escape is the only
                // dismiss path).
                MouseArea { anchors.fill: parent; onClicked: {} }
            }

            // Dialog card
            Rectangle {
                id: dialog
                anchors.centerIn: parent
                width: root.dialogWidth
                implicitHeight: root.dialogHeight > 0
                    ? root.dialogHeight
                    : (contentLoader.item ? contentLoader.item.implicitHeight : 0)
                        + Theme.dialogPadding * 2
                radius: Theme.dialogRadius
                color: Theme.glassBg()
                border.width: 1
                border.color: root.borderColor
                opacity: root.active ? 1 : 0
                scale: root.active ? 1 : 0.95

                Behavior on opacity { NumberAnimation { duration: Theme.animSmooth } }
                Behavior on scale {
                    SmoothAnim {}
                }

                transform: Translate { x: root.shakeOffsetX }

                // Caller-supplied content. The Loader instantiates the
                // Component per-screen so any IDs / Connections inside it
                // are unique per overlay (matches the behaviour of the
                // pre-refactor inline dialogs).
                Loader {
                    id: contentLoader
                    anchors.fill: parent
                    sourceComponent: root.contentComponent
                }
            }

            // Escape capture. Lives after the dialog so it doesn't steal
            // focus from explicitly-focused content fields. Content fields
            // that handle Keys.onEscapePressed themselves consume the event
            // before it reaches this Item — callers can either handle it
            // locally or leave it unhandled to bubble up to `dismissed()`.
            Item {
                anchors.fill: parent
                focus: root.active
                Keys.onEscapePressed: root.dismissed()
            }
        }
    }
}
