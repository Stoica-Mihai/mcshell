import QtQuick
import qs.Config

// Centered Nerd-Font glyph for a collapsed launcher card. Callers set
// `text` (the glyph), optionally `color`, and `visible`.
Text {
    anchors.centerIn: parent
    font.family: Theme.iconFont
    font.pixelSize: Theme.launcherIconCollapsed
    color: Theme.fgDim
}
