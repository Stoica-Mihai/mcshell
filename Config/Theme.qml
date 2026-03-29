pragma Singleton

import QtQuick
import Quickshell

Singleton {
    // ── Colors ──────────────────────────────────────────
    // Swap this block to change the entire shell's palette.

    // Background
    readonly property color bg: Qt.rgba(0.10, 0.10, 0.16, 0.85)
    readonly property color bgSolid: "#1a1b26"
    readonly property color bgHover: Qt.rgba(1, 1, 1, 0.08)

    // Foreground
    readonly property color fg: "#c0caf5"
    readonly property color fgDim: "#565f89"

    // Accent
    readonly property color accent: "#7aa2f7"

    // Semantic
    readonly property color red: "#f7768e"
    readonly property color green: "#9ece6a"
    readonly property color yellow: "#e0af68"
    readonly property color cyan: "#7dcfff"

    // Surface
    readonly property color border: Qt.rgba(1, 1, 1, 0.06)

    // ── Layout ──────────────────────────────────────────
    readonly property int barHeight: 34
    readonly property int barMargin: 5
    readonly property int barRadius: 10
    readonly property int itemSpacing: 14

    // ── Typography ──────────────────────────────────────
    readonly property string fontFamily: "JetBrains Mono"
    readonly property int fontSize: 13
    readonly property int fontSizeSmall: 11
    readonly property int iconSize: 16
}
