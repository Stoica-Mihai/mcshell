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

    // Index of `value` in `arr`, falling back to 0 (first item). When `field`
    // is given, matches arr[i][field]; otherwise matches the element itself.
    function indexInList(arr, value, field) {
        for (let i = 0; i < arr.length; i++) {
            const v = field ? arr[i][field] : arr[i];
            if (v === value) return i;
        }
        return 0;
    }

    // Step an index by `delta`, clamped to [0, len-1] (no wrap-around).
    function clampStep(i, delta, len) {
        return Math.max(0, Math.min(len - 1, i + delta));
    }

    function returnFocusToLauncher() {
        if (launcher && launcher.searchField) launcher.searchField.forceActiveFocus();
    }
}
