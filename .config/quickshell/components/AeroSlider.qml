import QtQuick
import qs.components

Item {
    id: root
    property real from: 0
    property real to: 100
    property real value: 0
    property real step: 1
    signal moved(real value)

    implicitHeight: 36

    function _setFromX(x) {
        var span = Math.max(1, width - thumb.width)
        var t = Math.max(0, Math.min(1, (x - thumb.width / 2) / span))
        var raw = from + t * (to - from)
        var stepped = Math.round(raw / step) * step
        var next = Math.max(from, Math.min(to, stepped))
        if (Math.abs(next - value) < 0.0001)
            return
        value = next
        moved(value)
    }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 14
        radius: 7
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.sheen(0.28) }
            GradientStop { position: 1; color: Theme.tint(Theme.glassDeep, 0.55) }
        }
        border.width: 1
        border.color: Theme.line

        Rectangle {
            height: parent.height
            width: Math.max(height, (root.value - root.from) / Math.max(0.0001, root.to - root.from) * parent.width)
            radius: 7
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.sheen(0.55) }
                GradientStop { position: 0.48; color: Theme.gelActive }
                GradientStop { position: 1; color: Theme.gelDeep }
            }
        }
    }

    Rectangle {
        id: thumb
        width: 28
        height: 28
        radius: 14
        y: (parent.height - height) / 2
        x: {
            var span = Math.max(1, root.width - width)
            var t = (root.value - root.from) / Math.max(0.0001, root.to - root.from)
            return Math.max(0, Math.min(span, t * span))
        }
        border.width: 1
        border.color: Theme.highlight
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.highlight }
            GradientStop { position: 0.45; color: Theme.gelHi }
            GradientStop { position: 1; color: Theme.gel }
        }
    }

    MouseArea {
        anchors.fill: parent
        onPressed: (mouse) => root._setFromX(mouse.x)
        onPositionChanged: (mouse) => {
            if (pressed)
                root._setFromX(mouse.x)
        }
    }
}
