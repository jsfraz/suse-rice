import QtQuick
import QtQuick.Controls
import qs.components

// Closed glossy field. The list hangs under it in the window, so a Flickable
// behind the page does not clip the choices.
Item {
    id: root
    property var labels: []
    property int currentIndex: 0
    signal picked(int index)

    implicitHeight: 44
    implicitWidth: 220

    readonly property string currentText: currentIndex >= 0 && currentIndex < labels.length
                                           ? String(labels[currentIndex]) : ""

    Rectangle {
        id: field
        anchors.fill: parent
        radius: height / 2
        border.width: 1
        border.color: Theme.line
        anchors.topMargin: menu.opened ? 2 : 0

        gradient: Gradient {
            GradientStop { position: 0; color: Theme.sheen(menu.opened ? 0.28 : 0.62) }
            GradientStop { position: 0.46; color: menu.opened ? Theme.gelDeep : Theme.gel }
            GradientStop { position: 0.52; color: menu.opened ? Theme.glassDeep : Theme.gelDeep }
            GradientStop { position: 1; color: Theme.glassDeep }
        }

        AeroSheen { strength: menu.opened ? 0.3 : 0.75 }

        Text {
            anchors.left: parent.left
            anchors.right: chevron.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 16
            anchors.rightMargin: 8
            text: root.currentText
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 16
            font.weight: 620
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            id: chevron
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: menu.opened ? "▴" : "▾"
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: 700
        }
    }

    MouseArea {
        anchors.fill: field
        onClicked: menu.opened ? menu.close() : menu.open()
    }

    Popup {
        id: menu
        parent: root.Window.window ? root.Window.window.contentItem : root
        width: root.width
        padding: 8
        modal: false
        dim: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        function place() {
            if (!parent)
                return
            var origin = root.mapToItem(parent, 0, 0)
            x = origin.x
            y = origin.y + root.height + 6
        }

        onAboutToShow: place()

        Timer {
            interval: 32
            repeat: true
            running: menu.opened
            onTriggered: menu.place()
        }

        background: Item {
            Rectangle {
                anchors.fill: parent
                anchors.margins: -6
                radius: 22
                color: Theme.shadow
                opacity: 0.35
            }
            Rectangle {
                anchors.fill: parent
                radius: Theme.radius
                border.width: 1
                border.color: Theme.line
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.sheen(0.36) }
                    GradientStop { position: 0.18; color: Theme.tint(Theme.glass, 0.52) }
                    GradientStop { position: 1; color: Theme.tint(Theme.glassDeep, 0.58) }
                }
                AeroSheen { curve: Theme.radius; strength: 0.7 }
            }
        }

        contentItem: Flickable {
            id: scroller
            contentWidth: width
            contentHeight: choices.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            ScrollBar.vertical: ScrollBar {
                policy: scroller.contentHeight > scroller.height + 1 ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                contentItem: Rectangle {
                    implicitWidth: 8
                    radius: 4
                    color: Theme.highlight
                    opacity: 0.85
                }
            }

            Column {
                id: choices
                width: scroller.width
                spacing: 4

                Repeater {
                    model: root.labels
                    delegate: Rectangle {
                        required property int index
                        required property var modelData
                        width: choices.width
                        height: 36
                        radius: height / 2
                        border.width: 1
                        border.color: index === root.currentIndex ? Theme.highlight : Theme.tint(Theme.rim, 0.35)
                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: index === root.currentIndex ? Theme.sheen(0.55) : Theme.sheen(0.12)
                            }
                            GradientStop {
                                position: 1
                                color: index === root.currentIndex ? Theme.gelActive : Theme.tint(Theme.glassDeep, 0.28)
                            }
                        }

                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            verticalAlignment: Text.AlignVCenter
                            text: String(modelData)
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.weight: 620
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.picked(index)
                                menu.close()
                            }
                        }
                    }
                }
            }
        }

        height: {
            var count = root.labels.length
            if (count < 1)
                return 52
            var content = count * 36 + (count - 1) * 4
            return Math.min(360, content + topPadding + bottomPadding)
        }
    }
}
