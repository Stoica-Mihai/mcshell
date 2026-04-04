import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Niri
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

    // ── Actions ──
    SafeProcess {
        id: lockProc
        command: ["qs", "-c", "mcshell", "ipc", "call", "mcshell", "lock"]
        failMessage: "lock failed"
    }
    SafeProcess {
        id: rebootProc
        command: ["systemctl", "reboot"]
        failMessage: "reboot failed"
    }
    SafeProcess {
        id: shutdownProc
        command: ["systemctl", "poweroff"]
        failMessage: "shutdown failed"
    }

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
    function resetSelection() { selectedItem = 0; confirmItem = -1; }
    property int confirmItem: -1  // which item is awaiting confirmation

    Timer {
        id: confirmReset
        interval: 3000
        onTriggered: root.confirmItem = -1
    }

    function activateItem() {
        if (selectedItem === 0) return;
        const actionIdx = selectedItem - 1;
        const action = actions[actionIdx];
        if (action.danger && confirmItem !== selectedItem) {
            confirmItem = selectedItem;
            confirmReset.restart();
            return;
        }
        confirmItem = -1;
        switch (actionIdx) {
        case 0: lockProc.running = true; break;
        case 1: Niri.dispatch(["quit", "--skip-confirmation"]); break;
        case 2: rebootProc.running = true; break;
        case 3: shutdownProc.running = true; break;
        }
    }

    // Power profile row
    SettingsRow {
        selected: root.active && root.selectedItem === 0
        opacity: root._profileAvailable ? 1.0 : Theme.opacityDim
        Layout.preferredHeight: 36

        Text {
            text: Theme.iconBattery
            font.family: Theme.iconFont
            font.pixelSize: 16
            color: Theme.accent
        }
        Text {
            text: "Profile"
            font.family: Theme.fontFamily
            font.pixelSize: 13
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
                selectedColor: modelData.danger ? Qt.rgba(0.97, 0.47, 0.56, 0.08) : Theme.overlay

                    Text {
                        text: modelData.icon
                        font.family: Theme.iconFont
                        font.pixelSize: 16
                        color: modelData.danger ? Theme.red : Theme.fg
                    }
                    Text {
                        text: root.confirmItem === (index + 1) ? "Confirm?" : modelData.name
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: root.confirmItem === (index + 1) ? Theme.red
                             : modelData.danger ? Theme.fg : Theme.fg
                        Layout.fillWidth: true
                    }
                    Text {
                        visible: modelData.danger && root.confirmItem !== (index + 1)
                        text: "confirm"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMini
                        color: Theme.fgDim
                        opacity: Theme.opacityDim
                    }
            }
        }

}
