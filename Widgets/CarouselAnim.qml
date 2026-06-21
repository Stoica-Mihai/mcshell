import QtQuick
import qs.Config

// Standard carousel transition: animCarousel duration, OutCubic easing.
// Use inside a Behavior: `Behavior on height { CarouselAnim {} }`.
NumberAnimation {
    duration: Theme.animCarousel
    easing.type: Easing.OutCubic
}
