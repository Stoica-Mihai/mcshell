import QtQuick
import qs.Config

// Small colored status dot with an animated color transition.
Rectangle {
    property int size: 6
    width: size
    height: size
    radius: size / 2

    Behavior on color { ColorAnimation { duration: Theme.animCarousel } }
}
