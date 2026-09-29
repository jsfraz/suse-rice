import QtQuick
import qs.components

Item {
    id: root
    property string text: ""
    property bool accent: true
    signal clicked

    implicitHeight: 42
    implicitWidth: Math.max(108, label.implicitWidth + 36)

    scale: pressed && enabled ? 0.97 : 1
    opacity: enabled ? 1 : 0.45

    property bool pressed: mouse.pressed

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: root.pressed && root.enabled ? 2 : 0
        radius: height / 2
        border.width: 1
        border.color: Theme.line

        gradient: Gradient {
            GradientStop { position: 0; color: Theme.sheen(root.pressed ? 0.22 : 0.62) }
            GradientStop {
                position: 0.46
                color: root.accent
                       ? (root.pressed ? Theme.gelDeep : Theme.gelActive)
                       : (root.pressed ? Theme.glassDeep : Theme.gel)
            }
            GradientStop {
                position: 0.52
                color: root.accent ? Theme.gelDeep : Theme.glassDeep
            }
            GradientStop { position: 1; color: Theme.glassDeep }
        }

        AeroSheen { strength: root.pressed ? 0.25 : 0.75 }

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 16
            font.weight: 600
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
