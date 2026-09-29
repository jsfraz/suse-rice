import QtQuick
import qs.components

// Highlight along the top rim. A straight bar sits under the curve of a capsule,
// so this strokes the same radius and only keeps the upper arc.
Item {
    id: root
    property real curve: -1
    property real strength: 0.75

    anchors.fill: parent

    readonly property real rim: curve < 0 ? height / 2 : curve

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 1
        anchors.rightMargin: 1
        anchors.topMargin: 1
        height: Math.min(parent.height - 2, root.rim + 2)
        clip: true

        Rectangle {
            width: parent.width
            height: Math.max(parent.height, root.height - 2)
            radius: root.curve < 0 ? height / 2 : Math.max(1, root.curve - 1)
            color: "transparent"
            border.width: 1
            border.color: Theme.highlight
            opacity: root.strength
            antialiasing: true
        }
    }
}
