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
    legendHint: editMode
        ? "\u2191 \u2193 Items  |  \u2190 \u2192 Adjust  |  Enter select  |  ESC browse"
        : "\u2190 \u2192 Category  |  \u2191 \u2193 Edit  |  ESC close"

    // ── Data ──
    readonly property var settingsCategories: [{id:"audio"},{id:"display"},{id:"power"}]
    model: settingsCategories

    property var activeSettingsCard: null
    property bool editMode: false

    // ── Lifecycle ──
    function onTabEnter() { editMode = false; }
    function onTabLeave() { editMode = false; }

    // ── Key handler ──
    function onKeyPressed(event) {
        if (editMode) {
            // Edit mode: Up/Down navigate items, Left/Right adjust, Enter activates, Escape exits
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
                return true;  // always consume in edit mode
            case Qt.Key_Right:
                if (activeSettingsCard.adjustRight) activeSettingsCard.adjustRight();
                return true;  // always consume in edit mode
            case Qt.Key_Escape:
                editMode = false;
                if (activeSettingsCard.resetSelection) activeSettingsCard.resetSelection();
                return true;
            }
            return false;
        } else {
            // Browse mode: Up/Down enters edit mode, Left/Right handled by AppLauncher
            switch (event.key) {
            case Qt.Key_Up:
            case Qt.Key_Down:
                editMode = true;
                return true;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                editMode = true;
                return true;
            }
            return false;
        }
    }

    // ── Activate ──
    function onActivate(index) {
        if (editMode && activeSettingsCard) activeSettingsCard.activateItem();
        else editMode = true;
    }

    // ── Card delegate ──
    cardDelegate: Component {
        CarouselStrip {
            selectedIndex: root.launcher.selectedIndex
            sideCount: root.launcher.sideCount
            expandedWidth: root.launcher.expandedWidth
            stripWidth: root.launcher.stripWidth
            carouselHeight: root.launcher.carouselHeight
            onActivated: { if (settingsCard.active) root.editMode = true; }
            onSelected: root.launcher.selectedIndex = index

            // Collapsed icon
            Text {
                anchors.centerIn: parent
                visible: !parent.isCurrent
                text: settingsCard.collapsedIcon
                font.family: Theme.iconFont
                font.pixelSize: 24
                color: Theme.fgDim
            }

            // Expanded content via SettingsCard
            SettingsCard {
                id: settingsCard
                anchors.fill: parent
                visible: parent.isCurrent
                category: modelData.id ?? ""
                active: parent.isCurrent && root.editMode

                onActiveChanged: {
                    if (active) root.activeSettingsCard = settingsCard;
                }
            }
        }
    }
}
