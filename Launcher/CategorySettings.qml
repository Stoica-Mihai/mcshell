import QtQuick
import QtQuick.Layouts
import qs.Config

LauncherCategory {
    id: root

    // ── Launcher reference ──
    required property var launcher

    // ── Tab config ──
    tabName: "settings"
    tabLabel: "Settings"
    tabIcon: Theme.iconSettings
    searchPlaceholder: "Settings"
    supportedModes: ["view", "list", "edit"]

    legendOverride: launcher.inEdit
    legendHint: launcher.inEdit
        ? activeSettingsCard?.panelLegend ?? ""
        : "Enter edit"

    // ── Data ──
    readonly property var settingsCategories: [
        { id: "audio",     icon: Theme.iconVolHigh,    source: "SettingsAudio.qml" },
        { id: "display",   icon: Theme.iconBrightness, source: "SettingsDisplay.qml" },
        { id: "wallpaper", icon: Theme.iconImage,      source: "SettingsWallpaper.qml" },
        { id: "theme",     icon: Theme.iconPalette,    source: "SettingsTheme.qml" },
        { id: "power",     icon: Theme.iconShutdown,   source: "SettingsPower.qml" }
    ]
    Component.onCompleted: setItems(settingsCategories)

    property var activeSettingsCard: null

    // ── Search ──
    function onSearch(text) {
        setItems(filterByQuery(text, settingsCategories,
            (item, q) => item.id.toLowerCase().indexOf(q) >= 0));
    }

    function onOpenTarget(target) {
        for (let i = 0; i < settingsCategories.length; i++) {
            if (settingsCategories[i].id === target) {
                launcher.selectedIndex = i;
                return;
            }
        }
    }

    function onKeyPressed(event) {
        if (!launcher.inEdit || !activeSettingsCard) return false;
        switch (event.key) {
        case Qt.Key_Up:
            activeSettingsCard.navigateUp();
            return true;
        case Qt.Key_Down:
            activeSettingsCard.navigateDown();
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (!event.isAutoRepeat) activeSettingsCard.activateItem();
            return true;
        case Qt.Key_Left:
            if (activeSettingsCard.adjustLeft) activeSettingsCard.adjustLeft();
            return true;
        case Qt.Key_Right:
            if (activeSettingsCard.adjustRight) activeSettingsCard.adjustRight();
            return true;
        case Qt.Key_Escape:
            if (activeSettingsCard.resetSelection) activeSettingsCard.resetSelection();
            return false;
        }
        return false;
    }

    function onKeyReleased(event) {
        if (launcher.inEdit && activeSettingsCard && !event.isAutoRepeat) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                activeSettingsCard.deactivateItem();
                return true;
            }
        }
        return false;
    }

    // ── Activate ──
    function onActivate(index) {
        if (launcher.inEdit && activeSettingsCard) activeSettingsCard.activateItem();
        else launcher.level = "edit";
    }

    // ── Card delegate ──
    cardDelegate: Component {
        CarouselStrip {
            launcher: root.launcher
            function onStripActivated() { if (settingsCard.active) root.launcher.level = "edit"; }

            // Collapsed icon
            Text {
                anchors.centerIn: parent
                visible: !parent.isCurrent
                text: modelData.icon ?? Theme.iconMissing
                font.family: Theme.iconFont
                font.pixelSize: Theme.launcherIconCollapsed
                color: Theme.fgDim
            }

            // Expanded content via SettingsCard
            SettingsCard {
                id: settingsCard
                anchors.fill: parent
                visible: parent.isCurrent
                source: modelData.source ?? ""
                active: parent.isCurrent && launcher.inEdit
                launcher: root.launcher
                onActiveChanged: {
                    if (active) root.activeSettingsCard = settingsCard;
                }
            }
        }
    }
}
