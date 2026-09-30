import QtQuick
import qs.components

Item {
    id: root
    property alias text: input.text
    property string placeholder: ""
    property bool password: false
    signal accepted

    implicitHeight: 34

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSm
        color: Theme.tint(Theme.glass, 0.4)
        border.width: 1
        border.color: input.activeFocus ? Theme.highlight : Theme.line

        AeroSheen { curve: Theme.radiusSm; strength: 0.65 }

        Text {
            anchors.fill: input
            text: root.placeholder
            color: Theme.inkSoft
            font: input.font
            visible: input.text.length === 0 && !input.activeFocus
            verticalAlignment: Text.AlignVCenter
        }

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: Text.AlignVCenter
            color: Theme.ink
            selectionColor: Theme.glossLow
            selectedTextColor: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: 560
            clip: true
            selectByMouse: true
            echoMode: root.password ? TextInput.Password : TextInput.Normal
            onAccepted: root.accepted()
        }
    }
}
