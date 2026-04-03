import QtQuick
import QtQuick.Layouts
import qs.Config

LauncherCategory {
    id: root

    // ── Launcher reference ──
    required property var launcher

    // ── Tab config ──
    tabLabel: "Settings"
    tabIcon: Theme.iconSettings
    searchPlaceholder: "Settings"
    legendOverride: editMode
    legendHint: editMode
        ? activeSettingsCard?.panelLegend ?? ""
        : "Enter edit"

    // ── Data ──
    readonly property var settingsCategories: [
        { id: "audio",   icon: Theme.iconVolHigh,    source: "SettingsAudio.qml" },
        { id: "display", icon: Theme.iconBrightness, source: "SettingsDisplay.qml" },
        { id: "theme",   icon: Theme.iconPalette,    source: "SettingsTheme.qml" },
        { id: "power",   icon: Theme.iconShutdown,   source: "SettingsPower.qml" }
    ]
    model: settingsCategories

    property var activeSettingsCard: null
    property bool editMode: false

    // ── Lifecycle ──
    function onTabEnter() { editMode = false; }
    function onTabLeave() { editMode = false; }

    // ── Key handler ──
    function onKeyPressed(event) {
        if (editMode) {
            // Sub-edit: Up/Down navigate items, Left/Right adjust, Enter activates, Escape exits
            if (!activeSettingsCard) return false;
            switch (event.key) {
            case Qt.Key_Up:
                activeSettingsCard.navigateUp();
                return true;
            case Qt.Key_Down:
                activeSettingsCard.navigateDown();
                return true;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                activeSettingsCard.activateItem();
                return true;
            case Qt.Key_Left:
                if (activeSettingsCard.adjustLeft) activeSettingsCard.adjustLeft();
                return true;
            case Qt.Key_Right:
                if (activeSettingsCard.adjustRight) activeSettingsCard.adjustRight();
                return true;
            case Qt.Key_Escape:
                editMode = false;
                if (activeSettingsCard.resetSelection) activeSettingsCard.resetSelection();
                return true;
            }
            return false;
        }
        // Level 2: Enter/Up/Down enters sub-edit (only when launcher is in edit mode)
        if (root.launcher.editMode) {
            switch (event.key) {
            case Qt.Key_Up:
            case Qt.Key_Down:
            case Qt.Key_Return:
            case Qt.Key_Enter:
                editMode = true;
                return true;
            }
        }
        return false;
    }

    // ── Activate ──
    function onActivate(index) {
        if (editMode && activeSettingsCard) activeSettingsCard.activateItem();
        else editMode = true;
    }

    // ── Card delegate ──
    cardDelegate: Component {
        CarouselStrip {
            launcher: root.launcher
            function onStripActivated() { if (settingsCard.active) root.editMode = true; }

            // Collapsed icon
            Text {
                anchors.centerIn: parent
                visible: !parent.isCurrent
                text: modelData.icon ?? Theme.iconMissing
                font.family: Theme.iconFont
                font.pixelSize: Theme.iconSizeSmall
                color: Theme.fgDim
            }

            // Expanded content via SettingsCard
            SettingsCard {
                id: settingsCard
                anchors.fill: parent
                visible: parent.isCurrent
                source: modelData.source ?? ""
                active: parent.isCurrent && root.editMode

                onActiveChanged: {
                    if (active) root.activeSettingsCard = settingsCard;
                }
            }
        }
    }
}
