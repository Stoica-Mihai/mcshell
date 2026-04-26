import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Widgets
import Quickshell.Services.UPower
import qs.Config
import qs.Core

// Power settings card content — power profile + lock, logout, reboot, shutdown.
SettingsPanel {
    id: root

    // ── Header ──
    readonly property string headerIcon: Theme.iconShutdown
    readonly property string headerTitle: "Power"
    readonly property string panelLegend: _confirmingItem >= 0
        ? Theme.legend(Theme.hintEnter + " cancel", Theme.hintBack)
        : Theme.legend(Theme.hintUpDown, Theme.hintAdjust, Theme.hintEnter + " activate", Theme.hintBack)
    readonly property string headerSubtitle: _profileAvailable ? profileNames[Math.max(0, _profileIndex)] : ""
    readonly property color headerColor: Theme.fg

    // ── Power Profile ──
    readonly property var profileNames: {
        const list = ["Power Saver", "Balanced"];
        if (PowerProfiles.hasPerformanceProfile) list.push("Performance");
        return list;
    }
    readonly property var profileEnums: {
        const list = [PowerProfile.PowerSaver, PowerProfile.Balanced];
        if (PowerProfiles.hasPerformanceProfile) list.push(PowerProfile.Performance);
        return list;
    }
    readonly property int _profileIndex: profileEnums.indexOf(PowerProfiles.profile)

    function adjustLeft() {
        if (!_profileAvailable || selectedItem !== 0) return false;
        profileCycler.cycleLeft();
        return true;
    }
    function adjustRight() {
        if (!_profileAvailable || selectedItem !== 0) return false;
        profileCycler.cycleRight();
        return true;
    }

    CyclePicker {
        id: profileCycler
        visible: false
        model: root.profileNames
        currentIndex: Math.max(0, root._profileIndex)
        onIndexChanged: idx => {
            PowerProfiles.profile = root.profileEnums[idx];
            UserSettings.powerProfile = root.profileNames[idx];
        }
    }

    // Restore saved profile on startup
    Connections {
        target: profileCheck
        function onFinished() {
            const saved = UserSettings.powerProfile;
            const idx = root.profileNames.indexOf(saved);
            if (idx >= 0) {
                PowerProfiles.profile = root.profileEnums[idx];
                profileCycler.currentIndex = idx;
            }
        }
    }

    // React to external config changes
    Connections {
        target: UserSettings
        function onPowerProfileChanged() {
            const idx = root.profileNames.indexOf(UserSettings.powerProfile);
            if (idx >= 0) {
                PowerProfiles.profile = root.profileEnums[idx];
                profileCycler.currentIndex = idx;
            }
        }
    }

    // ── Actions ──
    readonly property var actions: [
        { name: "Lock",     icon: Theme.iconLock,     danger: false, run: () => ShellActions.lock() },
        { name: "Log out",  icon: Theme.iconLogout,   danger: false, run: () => ShellActions.logout() },
        { name: "Reboot",   icon: Theme.iconReboot,   danger: true,  run: () => ShellActions.reboot() },
        { name: "Shutdown", icon: Theme.iconShutdown, danger: true,  run: () => ShellActions.shutdown() },
    ]

    property bool _profileAvailable: false
    SafeProcess {
        id: profileCheck
        command: ["busctl", "--system", "status", "org.freedesktop.UPower.PowerProfiles"]
        onFinished: root._profileAvailable = true
        onFailed: root._profileAvailable = false
        Component.onCompleted: running = true
    }
    itemCount: 5
    function resetSelection() { selectedItem = 0; _cancelConfirm(); }

    // ── Confirmation countdown ──
    // Danger actions (reboot, shutdown) arm a 3s countdown on first Enter,
    // fire when it expires, and cancel on a second Enter press.
    readonly property int _confirmDuration: 3000
    readonly property int _pillWidth: 48
    readonly property int _pillHeight: 22

    property int _confirmingItem: -1
    property real _confirmProgress: 0
    readonly property int _remainingSeconds: Math.ceil((1 - _confirmProgress) * (_confirmDuration / 1000))

    NumberAnimation {
        id: _confirmAnim
        target: root
        property: "_confirmProgress"
        from: 0; to: 1
        duration: root._confirmDuration
        easing.type: Easing.Linear
        onFinished: {
            const action = root.actions[root._confirmingItem - 1];
            root._cancelConfirm();
            action.run();
        }
    }

    function _cancelConfirm() {
        _confirmAnim.stop();
        _confirmingItem = -1;
        _confirmProgress = 0;
    }

    function activateItem() {
        if (selectedItem === 0) return;
        const action = actions[selectedItem - 1];

        if (!action.danger) {
            action.run();
            return;
        }

        // Second press while arming cancels.
        if (_confirmingItem === selectedItem) {
            _cancelConfirm();
            return;
        }

        _confirmingItem = selectedItem;
        _confirmAnim.start();
    }

    function deactivateItem() {}

    onSelectedItemChanged: {
        if (_confirmingItem >= 0 && selectedItem !== _confirmingItem)
            _cancelConfirm();
    }

    // Power profile row
    SettingsRow {
        selected: root.active && root.selectedItem === 0
        opacity: root._profileAvailable ? 1.0 : Theme.opacityDim
        Layout.preferredHeight: Theme.settingsRowCompact

        SettingsRow.Icon { text: Theme.iconTune; color: Theme.accent }
        SettingsRow.Label { text: "Profile"; Layout.fillWidth: true }
        CyclePicker {
            pillValue: true
            model: root.profileNames
            currentIndex: profileCycler.currentIndex
            enabled: root._profileAvailable
        }
    }

    Repeater {
        model: root.actions

        SettingsRow {
            required property var modelData
            required property int index
            selected: root.active && root.selectedItem === (index + 1)
            selectedColor: modelData.danger ? Theme.redLight : Theme.overlay

            readonly property bool _isConfirming: root._confirmingItem === (index + 1)
            readonly property color _confirmColor: Qt.rgba(
                Theme.accent.r + (Theme.red.r - Theme.accent.r) * root._confirmProgress,
                Theme.accent.g + (Theme.red.g - Theme.accent.g) * root._confirmProgress,
                Theme.accent.b + (Theme.red.b - Theme.accent.b) * root._confirmProgress,
                1.0)

            SettingsRow.Icon {
                text: modelData.icon
                font.pixelSize: Theme.fontSizeLarge
                color: modelData.danger ? Theme.red : Theme.fg
            }
            SettingsRow.Label {
                text: modelData.name
                font.pixelSize: Theme.fontSize
                Layout.fillWidth: true
            }

            // Hold-to-confirm pill (danger actions only) — parallelogram with
            // a left-to-right progress fill that follows the same slant.
            Item {
                visible: modelData.danger
                implicitWidth: root._pillWidth
                implicitHeight: root._pillHeight

                // Background pill
                SkewRect {
                    anchors.fill: parent
                    fillColor: Theme.accentLight
                    strokeColor: Theme.withAlpha(_isConfirming ? _confirmColor : Theme.accent, 0.4)
                    strokeWidth: 1
                }

                // Progress fill — own parallelogram with the same skew, so its
                // right edge follows the diagonal as it grows left-to-right.
                SkewRect {
                    visible: _isConfirming
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * root._confirmProgress
                    fillColor: _confirmColor
                }

                // Seconds countdown
                Text {
                    anchors.centerIn: parent
                    text: root._remainingSeconds
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMini
                    color: _isConfirming ? Theme.accentFg : Theme.fgDim
                }
            }
        }
    }
}
