import QtQuick
import qs.components

Rectangle {
    id: root
    property int pad: 10
    default property alias content: holder.data
    radius: Theme.radiusSm
    border.width: 1
    border.color: Theme.line
    implicitHeight: holder.implicitHeight + pad * 2
    gradient: Gradient {
        GradientStop { position: 0; color: Theme.cardTop }
        GradientStop { position: 0.16; color: Theme.tint(Theme.glass, 0.34) }
        GradientStop { position: 1; color: Theme.cardBottom }
    }

    AeroSheen { curve: Theme.radiusSm; strength: 0.7 }

    Column {
        id: holder
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.pad
        spacing: 6
    }
}
