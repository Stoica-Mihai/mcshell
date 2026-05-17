import QtQuick

// Optimized Image with sensible defaults for the shell.
// Enables async loading, aspect-crop fill, and decode-to-widget-size.
//
// sourceSize defaults to the widget's current width/height (with a 16-px
// guard so an Image laid out at zero size doesn't get cached at 0x0).
// Without this default, every callsite that forgets to override sourceSize
// decodes the source at its native resolution — a 4K JPEG used as a 160-px
// album art tile becomes a ~32 MB pixel buffer.
//
// Use sub-property bindings (sourceSize.width / sourceSize.height) here
// rather than the grouped `Qt.size(...)` form so callsites can override one
// dimension and let the other fall through to the widget-size default. Set
// `sourceSize.width: 0` (or .height) on a callsite to mean "unconstrained
// in that dimension" — Qt will then derive it from the aspect ratio.
//
// Use instead of raw Image throughout the project.
Image {
    asynchronous: true
    fillMode: Image.PreserveAspectCrop
    sourceSize.width: Math.max(16, width)
    sourceSize.height: Math.max(16, height)
}
