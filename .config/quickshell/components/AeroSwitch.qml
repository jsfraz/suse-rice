import QtQuick
import qs.components

Item {
    id: root
    property bool checked: false
    signal clicked

    implicitWidth: 68
    implicitHeight: 36
    opacity: enabled ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        border.width: 1
        border.color: Theme.line
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.sheen(0.55) }
            GradientStop { position: 0.48; color: root.checked ? Theme.gelActive : Theme.gel }
            GradientStop { position: 0.52; color: root.checked ? Theme.gelDeep : Theme.glassDeep }
            GradientStop { position: 1; color: Theme.glassDeep }
        }
        AeroSheen { strength: 0.7 }
    }

    Rectangle {
        width: 28
        height: 28
        radius: 14
        y: 4
        x: root.checked ? parent.width - width - 4 : 4
        border.width: 1
        border.color: Theme.tint(Theme.highlight, 0.85)
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.highlight }
            GradientStop { position: 0.45; color: Theme.gelHi }
            GradientStop { position: 1; color: Theme.gel }
        }
        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
