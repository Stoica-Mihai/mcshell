import QtQuick

// Optimized Image with sensible defaults for the shell.
// Enables mipmap, async loading, and aspect-crop fill by default.
// Use instead of raw Image throughout the project.
Image {
    asynchronous: true
    fillMode: Image.PreserveAspectCrop
}
