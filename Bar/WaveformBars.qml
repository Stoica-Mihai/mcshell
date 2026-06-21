import QtQuick
import qs.Config
import qs.Widgets

// Shared 8-bar waveform skeleton used by VolumeWaveform and SysWaveform.
// Callers feed in a heights array (0..1 ratios) via `model` and either
// a single `color` or a per-bar `colors` array. Using a model-driven
// Repeater instead of a callback lets QML diff updates per delegate
// rather than re-running a JS function on every parent property tick.
Row {
    id: root

    // Array of per-bar height ratios (0..1). Length should match `barCount`
    // (the inner Repeater treats undefined entries as 0).
    property var model: [0, 0, 0, 0, 0, 0, 0, 0]

    // Uniform color fallback, used when `colors` is null/undefined.
    property color color: Theme.accent
    // Optional per-bar colors array. When non-null, takes precedence over `color`.
    property var colors: null

    // Vertical scale applied to each ratio. 14 matches the prior magic
    // number that the callback consumers multiplied in directly.
    property real referenceHeight: 14
    // Minimum visible bar height — keeps the skeleton recognisable at 0%.
    property real minHeight: 2

    readonly property int barCount: Theme.waveformBarCount

    spacing: 1.5

    Repeater {
        model: root.barCount

        Rectangle {
            width: 2.5
            radius: 1
            anchors.bottom: parent.bottom
            height: {
                const v = (root.model && index < root.model.length) ? root.model[index] : 0;
                return Math.max(root.minHeight, v * root.referenceHeight);
            }
            color: (root.colors && index < root.colors.length) ? root.colors[index] : root.color

            Behavior on height { CarouselAnim {} }
            Behavior on color  { ColorAnimation  { duration: Theme.animCarousel } }
        }
    }
}
