import QtQuick
import QtQuick.Controls
import qs.components

Flickable {
    id: root
    property string heading: ""
    default property alias body: bodyCol.data

    contentWidth: width
    contentHeight: column.implicitHeight + 8
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    Column {
        id: column
        width: root.width - 8
        spacing: 14

        Text {
            width: parent.width
            text: root.heading
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 28
            font.weight: 650
            visible: root.heading.length > 0
        }

        Column {
            id: bodyCol
            width: parent.width
            spacing: 12
        }
    }

    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
        contentItem: Rectangle {
            implicitWidth: 10
            radius: 5
            color: Theme.highlight
            opacity: 0.8
            border.width: 1
            border.color: Theme.gel
        }
    }
}
