//@ pragma IconTheme Papirus
//@ pragma Env QML_IMPORT_PATH=/home/mcs/.local/share/quickshell/plugins

import QtQuick
import Quickshell
import Quickshell.DBus
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import qs.Config
import qs.Bar
import qs.Notifications
import qs.Launcher
import qs.LockScreen
import qs.Polkit
import qs.Bluetooth
import qs.Screencast
import Quickshell.Services.Portal
import qs.Wallpaper
import qs.Screenshot
import Qs.DataControl
import qs.Core
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.SysInfo

ShellRoot {
    id: shell
    property string _togglePanel: ""
    property string _toggleMode: ""
    property int _toggleCounter: 0

    // First entry in each list is the default when the caller passes an empty mode.
    // Launcher tabs are not listed here — they declare modes on each LauncherCategory.
    // Authoritative SysInfo poll bindings. Bound once at the shell level
    // (not per-screen) so multiple bars don't race on the same singleton.
    // enabled=false stops the singleton from scraping /proc, /sys, hwmon,
    // and NVML in the background when no consumer needs the values.
    Binding {
        target: SysInfo
        property: "enabled"
        value: UserSettings.sysInfoEnabled
    }
    Binding {
        target: SysInfo
        property: "interval"
        value: UserSettings.sysInfoInterval
    }

    readonly property var _panelModes: ({
        weather:         ["view", "edit"],
        calendar:        ["view"],
        clockSettings:   ["view"],
        sysInfoSettings: ["view"],
        wifiSettings:    ["view"],
        bluetoothSettings: ["view"],
        keybinds:        ["view"],
        volume:          ["view"],
        notifications:   ["view"],
        media:           ["view"],
        tray:            ["view"],
        trayicons:       ["view"],
        sysinfo:         ["view"]
    })

    // Validate a mode against a panel/tab's supported modes. Returns the
    // resolved mode string (falls back to modes[0] when empty), or null
    // if the kind is unknown or the mode is unsupported — in both cases
    // a console.warn is emitted with the "mcshell IPC:" prefix that
    // test.sh's WARN filter relies on.
    function _resolveMode(kind, name, modes, mode) {
        if (!modes || modes.length === 0) {
            console.warn(`mcshell IPC: unknown ${kind} '${name}'`);
            return null;
        }
        const resolved = mode || modes[0];
        if (modes.indexOf(resolved) < 0) {
            console.warn(`mcshell IPC: ${kind} '${name}' does not support mode '${resolved}' (valid: ${modes.join(", ")})`);
            return null;
        }
        return resolved;
    }

    function _dispatchPanel(name, mode) {
        const resolved = _resolveMode("panel", name, _panelModes[name], mode);
        if (resolved === null) return;
        shell._togglePanel = name;
        shell._toggleMode = resolved;
        shell._toggleCounter++;
    }

    function _ensureLauncher() { appLauncherLoader.active = true; }

    function _toggleLauncher() {
        _ensureLauncher();
        appLauncherLoader.item.toggle();
    }

    function _dispatchLauncher(tab, mode, target) {
        _ensureLauncher();
        const al = appLauncherLoader.item;
        const resolved = _resolveMode("launcher tab", tab, al.supportedModesFor(tab), mode || "");
        if (resolved === null) return;
        al.openTab(tab, resolved, target || "");
    }

    // Force singleton initialization so connection watchers start immediately.
    // Also create IdleMonitor dynamically (ext-idle-notify-v1 — not in stock quickshell).
    Component.onCompleted: {
        NotificationDispatcher;
        // Force ScreenCastPortal init so the impl-portal ScreenCast adaptor
        // registers on the bus. Skeleton stage — all slots currently
        // respond with response=2 (other-error). See PLAN-screencast-portal.md.
        ScreenCastPortal;
        try {
            Qt.createQmlObject(
                'import Quickshell; IdleMonitor {'
                + ' enabled: UserSettings.loaded && UserSettings.idleTimeout > 0;'
                + ' timeout: Math.max(UserSettings.idleTimeout, 1) * 60;'
                + ' onIsIdleChanged: if (isIdle && !lockScreen.isLocked) lockScreen.lock();'
                + '}', root, "IdleMonitor");
        } catch (e) {}
    }
    // Watch the launcher's open state at shell level so each StatusBar can
    // dismiss its bar dropdowns when the launcher opens — otherwise the
    // dropdown just sits on top of the launcher's fullscreen surface.
    readonly property bool _launcherOpen: appLauncherLoader.item ? appLauncherLoader.item.isOpen : false

    Variants {
        model: Quickshell.screens

        StatusBar {
            required property var modelData
            screen: modelData
            screenName: modelData.name
            unreadNotifications: notifPopup.unreadCount
            notifHistoryModel: notifPopup.historyModel
            mediaPlaying: shell._mediaPlaying
            isRecording: recordingLoader.item?.active ?? false
            launcherOpen: shell._launcherOpen
            onLauncherRequested: shell._toggleLauncher()
            onWifiRequested: shell._dispatchLauncher("wifi", "", "")
            onBluetoothRequested: shell._dispatchLauncher("bluetooth", "", "")
            onNotifRemoved: nid => notifPopup.removeHistoryById(nid)
            onNotifCleared: notifPopup.clearHistory()
            onNotifPanelOpened: notifPopup.markAllRead()
            panelToggleTrigger: shell._toggleCounter
            panelToggleName: shell._togglePanel
            panelToggleMode: shell._toggleMode
        }
    }

    NotificationPopup { id: notifPopup }
    LockScreen {
        id: lockScreen
        Component.onCompleted: ShellActions.lockScreen = lockScreen
    }
    PolkitDialog {}
    BluetoothPairingDialog {}

    // xdg-desktop-portal Screenshot bridge.
    // The mcs-qs ScreenshotPortal singleton claims the impl-portal service
    // on startup and emits requestReceived for each app screenshot. We
    // route to ScreenshotOverlay — interactive=true falls through to the
    // area-selection UI, otherwise a fullscreen capture happens immediately
    // — and reply with the file:// URI once the overlay reports the save.
    property var _portalRequest: null
    Connections {
        target: ScreenshotPortal
        function onRequestReceived(req) {
            if (shell._portalRequest && !shell._portalRequest.answered) {
                shell._portalRequest.fail();
            }
            shell._portalRequest = req;
            if (req.interactive) {
                screenshot.captureArea();
            } else {
                screenshot.captureFullScreen();
            }
        }
    }
    Connections {
        target: screenshot
        function onCaptured(filePath) {
            if (shell._portalRequest && !shell._portalRequest.answered) {
                shell._portalRequest.respondWithFile("file://" + filePath);
            }
            shell._portalRequest = null;
        }
        function onCaptureFailed() {
            if (shell._portalRequest && !shell._portalRequest.answered) {
                shell._portalRequest.cancel();
            }
            shell._portalRequest = null;
        }
    }

    // ScreenCast picker dialog — themed overlay rendered when the portal
    // emits `pickerRequested`. Single component, owns its own request
    // state. See Screencast/ScreenCastPickerDialog.qml.
    ScreenCastPickerDialog {}

    WallpaperRenderer {
        id: wallpaper
        Component.onCompleted: ShellActions.wallpaper = wallpaper
    }
    WallpaperRotator {
        locked: lockScreen.isLocked
    }
    ScreenshotOverlay { id: screenshot }

    // Lazy-loaded transient overlays — parsed on first use, kept after.
    Component { id: _appLauncherComponent; AppLauncher {} }
    Component { id: _recordingComponent; Recording {} }
    Loader { id: appLauncherLoader; active: false; sourceComponent: _appLauncherComponent }
    Loader { id: recordingLoader; active: false; sourceComponent: _recordingComponent }

    function _toggleRecording() { recordingLoader.active = true; recordingLoader.item.toggleRecording(); }

    // IdleMonitor created dynamically in Component.onCompleted above

    // Media inhibitor: true when any MPRIS player is actively playing
    readonly property bool _mediaPlaying: {
        if (!Mpris.players || !Mpris.players.values) return false;
        const all = Mpris.players.values;
        for (let i = 0; i < all.length; i++)
            if (all[i].playbackState === MprisPlaybackState.Playing) return true;
        return false;
    }

    // ── Screenshot functions ────────────────────────────
    function screenshotFull() { screenshot.captureFullScreen(); }
    function screenshotArea() { screenshot.captureArea(); }

    property string _windowScreenshotPath: ""
    function screenshotWindow() {
        _windowScreenshotPath = Theme.screenshotPrefix + Date.now() + ".png";
        _windowScreenshotProc.command = ["niri", "msg", "action", "screenshot-window", "--path", _windowScreenshotPath];
        _windowScreenshotProc.running = true;
    }
    Process {
        id: _windowScreenshotProc
        onExited: (code, status) => {
            if (code === 0) {
                Quickshell.setClipboardImage(shell._windowScreenshotPath);
                NotificationDispatcher.sendWithImage("Screenshot", "Window copied to clipboard", shell._windowScreenshotPath);
            }
        }
    }

    // D-Bus mirror of the shell IPC surface + a few read-only state properties.
    //   busctl --user introspect com.mcshell.Shell /Shell
    //   busctl --user call com.mcshell.Shell /Shell com.mcshell.Shell ToggleVolume s view
    //   busctl --user get-property com.mcshell.Shell /Shell com.mcshell.Shell DoNotDisturb
    //   busctl --user monitor com.mcshell.Shell    # watch PropertiesChanged
    DBusIpcHandler {
        service: "com.mcshell.Shell"
        path: "/Shell"
        iface: "com.mcshell.Shell"

        // Methods
        function toggleLauncher(): void { shell._toggleLauncher(); }
        function lock(): void { ShellActions.lock(); }
        function toggleDnd(): void { UserSettings.doNotDisturb = !UserSettings.doNotDisturb; }
        function toggleVolume(mode: string): void { shell._dispatchPanel("volume", mode); }
        function toggleNotifications(mode: string): void { shell._dispatchPanel("notifications", mode); }
        function toggleSysInfo(mode: string): void { shell._dispatchPanel("sysinfo", mode); }
        function toggleBluetooth(): void { const a = Bluetooth.defaultAdapter; if (a) a.enabled = !a.enabled; }
        function toggleWifi(): void { Networking.wifiEnabled = !Networking.wifiEnabled; }

        // Read-only state — PropertiesChanged fires automatically from notify signals.
        property bool doNotDisturb: UserSettings.doNotDisturb
        property bool bluetoothEnabled: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
        property bool wifiEnabled: Networking.wifiEnabled

        // Signals — emitted by the shell when major state transitions happen.
        signal launcherOpened()
    }

    // IPC — qs -c mcshell ipc call mcshell <function>
    IpcHandler {
        target: "mcshell"

        function toggleLauncher(): void { shell._toggleLauncher(); }
        // Two positional args: <mode> <target>. Both optional (mcs-qs allows fewer args than declared).
        function launcherApps(mode: string, target: string): void { shell._dispatchLauncher("apps", mode, target); }
        function launcherClipboard(mode: string, target: string): void { shell._dispatchLauncher("clipboard", mode, target); }
        function launcherWifi(mode: string, target: string): void { shell._dispatchLauncher("wifi", mode, target); }
        function launcherBluetooth(mode: string, target: string): void { shell._dispatchLauncher("bluetooth", mode, target); }
        function launcherWallpaper(mode: string, target: string): void { shell._dispatchLauncher("wallpaper", mode, target); }
        function launcherSettings(mode: string, target: string): void { shell._dispatchLauncher("settings", mode, target); }

        function toggleKeybinds(mode: string): void { shell._dispatchPanel("keybinds", mode); }
        function lock(): void { ShellActions.lock(); }
        function toggleDnd(): void { UserSettings.doNotDisturb = !UserSettings.doNotDisturb; }
        function setWallpaper(path: string): void { ShellActions.setWallpaper(path); }

        function toggleCalendar(mode: string): void { shell._dispatchPanel("calendar", mode); }
        function toggleVolume(mode: string): void { shell._dispatchPanel("volume", mode); }
        function toggleNotifications(mode: string): void { shell._dispatchPanel("notifications", mode); }
        function toggleWeather(mode: string): void { shell._dispatchPanel("weather", mode); }
        function toggleClockSettings(mode: string): void { shell._dispatchPanel("clockSettings", mode); }
        function toggleSysInfo(mode: string): void { shell._dispatchPanel("sysinfo", mode); }
        function toggleSysInfoSettings(mode: string): void { shell._dispatchPanel("sysInfoSettings", mode); }
        function toggleWifiSettings(mode: string): void { shell._dispatchPanel("wifiSettings", mode); }
        function toggleBluetoothSettings(mode: string): void { shell._dispatchPanel("bluetoothSettings", mode); }
        function toggleTray(mode: string): void { shell._dispatchPanel("trayicons", mode); }
        function toggleRecording(): void { shell._toggleRecording(); }
        function clipboardList(): string {
            const entries = ClipboardHistory.entries.values;
            const lines = [];
            for (let i = 0; i < entries.length; i++) {
                const e = entries[i];
                lines.push(`${i}\t${e.mimeType}\t${e.content.substring(0, 100)}`);
            }
            return lines.join("\n");
        }
        function screenshotFull(): void { shell.screenshotFull(); }
        function screenshotArea(): void { shell.screenshotArea(); }
        function screenshotWindow(): void { shell.screenshotWindow(); }

        function toggleBluetooth(): void { const a = Bluetooth.defaultAdapter; if (a) a.enabled = !a.enabled; }
        function toggleWifi(): void { Networking.wifiEnabled = !Networking.wifiEnabled; }
    }
}
