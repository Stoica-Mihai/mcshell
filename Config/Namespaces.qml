pragma Singleton

import QtQuick
import Quickshell

// Central registry of Wayland layer-shell namespace strings. All `mcshell-*`
// surfaces reference these so the prefix can be renamed in one place and
// the full namespace set can be audited by reading this file.
Singleton {
    readonly property string _prefix: "mcshell"

    readonly property string root:             _prefix
    readonly property string barZone:          _prefix + "-zone"
    readonly property string launcher:         _prefix + "-launcher"
    readonly property string polkit:           _prefix + "-polkit"
    readonly property string screenshot:       _prefix + "-screenshot"
    readonly property string wallpaper:        _prefix + "-wallpaper"
    readonly property string notifications:    _prefix + "-notifications"
}
