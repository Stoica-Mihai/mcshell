import QtQuick
import QtQuick.Layouts
import qs.Config

// Base component for settings sub-panels. Provides shared keyboard
// navigation (up/down/reset) so panels only define itemCount and
// override activateItem / adjustLeft / adjustRight as needed.
ColumnLayout {
    property bool active: false
    property int selectedItem: 0
    property int itemCount: 0
    property var launcher: null

    spacing: Theme.spacingTiny

    function resetSelection() { selectedItem = 0; }
    function navigateUp() { selectedItem = selectedItem > 0 ? selectedItem - 1 : itemCount - 1; }
    function navigateDown() { selectedItem = selectedItem < itemCount - 1 ? selectedItem + 1 : 0; }
    function activateItem() {}
    function adjustLeft() { return false; }
    function adjustRight() { return false; }

    function returnFocusToLauncher() {
        if (launcher && launcher.searchField) launcher.searchField.forceActiveFocus();
    }
}
