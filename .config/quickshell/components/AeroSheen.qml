import QtQuick
import qs.components

// Highlight along the top rim. A straight bar sits under the curve of a capsule,
// so this strokes the same radius and only keeps the upper arc.
Item {
    id: root
    property real curve: -1
    property real strength: 0.75
    property color color: Theme.highlight
    property real inset: 1

    anchors.fill: parent

    readonly property real rim: curve < 0 ? height / 2 : curve

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: root.inset
        anchors.rightMargin: root.inset
        anchors.topMargin: root.inset
        height: Math.min(parent.height - 2, root.rim + 2)
        clip: true

        Rectangle {
            width: parent.width
            height: Math.max(parent.height, root.height - 2)
            radius: root.curve < 0 ? height / 2 : Math.max(1, root.curve - root.inset)
            color: "transparent"
            border.width: 1
            border.color: root.color
            opacity: root.strength * (Theme.lightType ? 0.42 : 1)
            antialiasing: true
        }
    }
}
