import QtQuick
import QtQuick.Layouts
import qs.Config

// Uppercase section label for settings panels (e.g. "OUTPUT", "INPUT").
Text {
    required property string label

    text: label
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSizeMini
    color: Theme.fgDim
    Layout.leftMargin: Theme.spacingLarge
    Layout.topMargin: 2
    opacity: Theme.opacitySubtle
}
