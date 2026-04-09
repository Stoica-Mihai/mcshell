import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
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
    readonly property string panelLegend: Theme.legend(Theme.hintUpDown, Theme.hintAdjust, Theme.hintEnter + " activate", Theme.hintBack)
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
        { name: "Lock", icon: Theme.iconLock, danger: false },
        { name: "Log out", icon: Theme.iconLogout, danger: false },
        { name: "Reboot", icon: Theme.iconReboot, danger: true },
        { name: "Shutdown", icon: Theme.iconShutdown, danger: true },
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
    function resetSelection() { selectedItem = 0; _cancelHold(); }

    // ── Hold-to-confirm countdown ──
    readonly property int _holdDuration: 3000
    readonly property int _ringSize: 36
    readonly property real _ringCenter: _ringSize / 2
    readonly property real _ringRadius: (_ringSize - _ringStroke) / 2
    readonly property real _ringStroke: 2.5

    property int _holdingItem: -1
    property real _holdProgress: 0

    NumberAnimation {
        id: _holdAnim
        target: root
        property: "_holdProgress"
        from: 0; to: 1
        duration: root._holdDuration
        easing.type: Easing.Linear
        onFinished: root._executeHeldAction()
    }

    function _cancelHold() {
        _holdAnim.stop();
        _holdingItem = -1;
        _holdProgress = 0;
    }

    function _executeHeldAction() {
        const actionIdx = _holdingItem - 1;
        _cancelHold();
        switch (actionIdx) {
        case 0: ShellActions.lock(); break;
        case 1: ShellActions.logout(); break;
        case 2: ShellActions.reboot(); break;
        case 3: ShellActions.shutdown(); break;
        }
    }

    function activateItem() {
        if (selectedItem === 0) return;
        if (_holdingItem >= 0) return; // already holding, ignore auto-repeat
        const actionIdx = selectedItem - 1;
        const action = actions[actionIdx];

        // Non-danger: fire immediately
        if (!action.danger) {
            switch (actionIdx) {
            case 0: ShellActions.lock(); break;
            case 1: ShellActions.logout(); break;
            }
            return;
        }

        // Danger: start hold countdown
        _holdingItem = selectedItem;
        _holdAnim.start();
    }

    function deactivateItem() {
        // Key released — cancel if still counting down
        if (_holdingItem >= 0) _cancelHold();
    }

    // Cancel hold when navigating away
    onSelectedItemChanged: {
        if (_holdingItem >= 0 && selectedItem !== _holdingItem)
            _cancelHold();
    }

    // Power profile row
    SettingsRow {
        selected: root.active && root.selectedItem === 0
        opacity: root._profileAvailable ? 1.0 : Theme.opacityDim
        Layout.preferredHeight: Theme.settingsRowCompact

        Text {
            text: Theme.iconBattery
            font.family: Theme.iconFont
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.accent
        }
        Text {
            text: "Profile"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.fg
            Layout.fillWidth: true
        }
        CyclePicker {
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

            readonly property bool _isHolding: root._holdingItem === (index + 1)

            Text {
                text: modelData.icon
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSizeLarge
                color: modelData.danger ? Theme.red : Theme.fg
            }
            Text {
                text: modelData.name
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                color: Theme.fg
                Layout.fillWidth: true
            }

            // Hold-to-confirm ring (danger actions only)
            Item {
                visible: modelData.danger
                implicitWidth: root._ringSize
                implicitHeight: root._ringSize

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    // Background ring
                    ShapePath {
                        fillColor: "transparent"
                        strokeWidth: root._ringStroke
                        strokeColor: Theme.accentLight
                        PathAngleArc {
                            centerX: root._ringCenter
                            centerY: root._ringCenter
                            radiusX: root._ringRadius
                            radiusY: root._ringRadius
                            startAngle: -90
                            sweepAngle: 360
                        }
                    }

                    // Progress ring — color transitions accent → red over time
                    ShapePath {
                        fillColor: "transparent"
                        strokeWidth: root._ringStroke
                        capStyle: ShapePath.RoundCap
                        strokeColor: _isHolding
                            ? Qt.rgba(
                                Theme.accent.r + (Theme.red.r - Theme.accent.r) * root._holdProgress,
                                Theme.accent.g + (Theme.red.g - Theme.accent.g) * root._holdProgress,
                                Theme.accent.b + (Theme.red.b - Theme.accent.b) * root._holdProgress,
                                1.0)
                            : "transparent"
                        PathAngleArc {
                            centerX: root._ringCenter
                            centerY: root._ringCenter
                            radiusX: root._ringRadius
                            radiusY: root._ringRadius
                            startAngle: -90
                            sweepAngle: _isHolding ? root._holdProgress * 360 : 0
                        }
                    }
                }

                // "hold" text inside ring
                Text {
                    anchors.centerIn: parent
                    text: "hold"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMini
                    color: _isHolding
                        ? Qt.rgba(
                            Theme.accent.r + (Theme.red.r - Theme.accent.r) * root._holdProgress,
                            Theme.accent.g + (Theme.red.g - Theme.accent.g) * root._holdProgress,
                            Theme.accent.b + (Theme.red.b - Theme.accent.b) * root._holdProgress,
                            1.0)
                        : Theme.fgDim
                }
            }
        }
    }
}
