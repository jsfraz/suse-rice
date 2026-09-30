import QtQuick
import qs.components

Item {
    id: root
    property string text: ""
    property bool accent: true
    property bool selected: false
    signal clicked

    implicitHeight: 32
    implicitWidth: Math.max(88, label.implicitWidth + 28)

    scale: !enabled ? 1 : pressed ? 0.96 : mouse.containsMouse ? 1.035 : 1
    opacity: enabled ? 1 : 0.45
    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }

    property bool pressed: mouse.pressed

    Rectangle {
        id: glow
        visible: root.selected && root.enabled
        x: face.x - 5
        y: face.y + 2
        width: face.width + 10
        height: face.height + 8
        radius: height / 2
        color: Theme.tint(Theme.gelActive, root.pressed ? 0.2 : 0.72)
    }

    Rectangle {
        id: face
        anchors.fill: parent
        anchors.topMargin: root.pressed && root.enabled ? 2 : 0
        Behavior on anchors.topMargin { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        radius: height / 2
        border.width: root.selected ? 2 : 1
        border.color: root.selected ? Theme.highlight : Theme.line

        gradient: Gradient {
            GradientStop { position: 0; color: Theme.sheen(root.selected ? 0.95 : (root.pressed ? 0.22 : 0.62)) }
            GradientStop {
                position: root.selected ? 0.22 : 0.46
                color: root.selected
                       ? (root.pressed ? Theme.gelActive : Theme.gloss(Theme.gelHi))
                       : (root.accent
                          ? (root.pressed ? Theme.gelDeep : Theme.gelActive)
                          : (root.pressed ? Theme.glassDeep : Theme.gloss(Theme.gel)))
            }
            GradientStop {
                position: root.selected ? 0.55 : 0.52
                color: root.selected
                       ? (root.pressed ? Theme.gelDeep : Theme.gelActive)
                       : (root.accent ? Theme.gelDeep : Theme.glassDeep)
            }
            GradientStop { position: 1; color: root.selected ? Theme.gelDeep : Theme.glassDeep }
        }

        AeroSheen { strength: root.selected ? 1 : (root.pressed ? 0.25 : 0.75) }
        AeroGlint { id: glint }

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: root.selected ? 750 : 600
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        onEntered: glint.play()
        onClicked: root.clicked()
    }
}
