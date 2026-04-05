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
    signal actionRequested(string action)

    spacing: Theme.spacingTiny

    function resetSelection() { selectedItem = 0; }
    function navigateUp() { if (selectedItem > 0) selectedItem--; }
    function navigateDown() { if (selectedItem < itemCount - 1) selectedItem++; }
    function activateItem() {}
    function adjustLeft() { return false; }
    function adjustRight() { return false; }
}
