import QtQuick
import qs.components

// A single lens streak. Call play() on hover or when a gel surface settles.
Item {
    id: root
    anchors.fill: parent
    clip: true

    function play() {
        if (width < 2)
            return
        sweep.from = -streak.width
        sweep.to = width + 4
        sweep.restart()
    }

    Rectangle {
        id: streak
        width: Math.max(28, root.width * 0.42)
        height: root.height * 2.4
        y: -root.height * 0.7
        x: -width
        rotation: 18
        opacity: Theme.lightType ? 0.35 : 0.7
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.46; color: Theme.tint(Theme.highlight, Theme.lightType ? 0.06 : 0.15) }
            GradientStop { position: 0.5; color: Theme.tint(Theme.highlight, Theme.lightType ? 0.32 : 0.95) }
            GradientStop { position: 0.54; color: Theme.tint(Theme.highlight, Theme.lightType ? 0.06 : 0.15) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    NumberAnimation {
        id: sweep
        target: streak
        property: "x"
        duration: 680
        easing.type: Easing.InOutQuad
    }
}
