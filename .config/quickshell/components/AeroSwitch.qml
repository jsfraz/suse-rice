import QtQuick
import qs.components

Item {
    id: root
    property bool checked: false
    signal clicked

    implicitWidth: 52
    implicitHeight: 28
    opacity: enabled ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        border.width: 1
        border.color: Theme.line
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.sheen(0.55) }
            GradientStop { position: 0.48; color: root.checked ? Theme.gelActive : Theme.gloss(Theme.gel) }
            GradientStop { position: 0.52; color: root.checked ? Theme.gelDeep : Theme.glassDeep }
            GradientStop { position: 1; color: Theme.glassDeep }
        }
        AeroSheen { strength: 0.7 }
    }

    Rectangle {
        width: 20
        height: 20
        radius: 10
        y: 4
        x: root.checked ? parent.width - width - 4 : 4
        border.width: 1
        border.color: Theme.tint(Theme.highlight, 0.85)
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.gloss(Theme.highlight) }
            GradientStop { position: 0.45; color: Theme.gloss(Theme.gelHi) }
            GradientStop { position: 1; color: Theme.gel }
        }
        Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }
        scale: mouse.pressed ? 0.92 : 1
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
