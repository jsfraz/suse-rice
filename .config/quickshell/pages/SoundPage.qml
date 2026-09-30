import QtQuick
import Quickshell.Services.Pipewire
import qs.components

Item {
    id: root
    property var sinks: []
    property var sources: []
    property var streams: []

    function labelFor(node) {
        if (!node)
            return ""
        var props = node.properties || {}
        return props["application.name"] || node.description || node.nickname || node.name || "Sound"
    }

    function sameList(a, b) {
        if (a.length !== b.length)
            return false
        for (var i = 0; i < a.length; i++) {
            if (a[i] !== b[i])
                return false
        }
        return true
    }

    function refresh() {
        var values = Pipewire.nodes.values
        var nextSinks = values.filter(function(n) { return n.audio && n.isSink && !n.isStream })
        var nextSources = values.filter(function(n) { return n.audio && !n.isSink && !n.isStream })
        var nextStreams = values.filter(function(n) { return n.audio && n.isStream })
        if (!sameList(sinks, nextSinks))
            sinks = nextSinks
        if (!sameList(sources, nextSources))
            sources = nextSources
        if (!sameList(streams, nextStreams))
            streams = nextStreams
        var tracked = []
        if (Pipewire.defaultAudioSink)
            tracked.push(Pipewire.defaultAudioSink)
        if (Pipewire.defaultAudioSource)
            tracked.push(Pipewire.defaultAudioSource)
        tracker.objects = tracked.concat(sinks).concat(sources).concat(streams)
    }

    PwObjectTracker { id: tracker }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Page {
        anchors.fill: parent
        anchors.rightMargin: 12
        heading: "Sound"

        AeroCard {
            width: parent.width
            SectionLabel { text: "Output"; width: parent.width }
            BodyText {
                width: parent.width
                visible: root.sinks.length === 0
                text: "No output. PipeWire is not running, or it is not ready yet."
            }
            Repeater {
                model: root.sinks
                delegate: Column {
                    required property var modelData
                    width: parent.width
                    spacing: 6
                    Row {
                        width: parent.width
                        spacing: 8
                        Text {
                            width: parent.width - 140
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.labelFor(modelData) + (modelData === Pipewire.defaultAudioSink ? "  ·  default" : "")
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.weight: 620
                            elide: Text.ElideRight
                        }
                        AeroButton {
                            text: "Select"
                            accent: modelData !== Pipewire.defaultAudioSink
                            enabled: modelData !== Pipewire.defaultAudioSink
                            onClicked: Pipewire.preferredDefaultAudioSink = modelData
                        }
                    }
                    Item {
                        id: sinkRow
                        width: parent.width
                        height: 34
                        readonly property int muteWidth: 148
                        AeroSlider {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(80, sinkRow.width - sinkRow.muteWidth - 12)
                            from: 0
                            to: 150
                            step: 1
                            value: modelData.audio ? Math.round(modelData.audio.volume * 100) : 0
                            onMoved: (v) => { if (modelData.audio) modelData.audio.volume = v / 100 }
                        }
                        AeroButton {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: sinkRow.muteWidth
                            text: modelData.audio && modelData.audio.muted ? "Muted" : "Sound"
                            accent: !(modelData.audio && modelData.audio.muted)
                            onClicked: { if (modelData.audio) modelData.audio.muted = !modelData.audio.muted }
                        }
                    }
                }
            }
        }

        AeroCard {
            width: parent.width
            SectionLabel { text: "Microphone"; width: parent.width }
            BodyText {
                width: parent.width
                visible: root.sources.length === 0
                text: "No microphone."
            }
            Repeater {
                model: root.sources
                delegate: Column {
                    required property var modelData
                    width: parent.width
                    spacing: 6
                    Row {
                        width: parent.width
                        spacing: 8
                        Text {
                            width: parent.width - 140
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.labelFor(modelData) + (modelData === Pipewire.defaultAudioSource ? "  ·  default" : "")
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.weight: 620
                            elide: Text.ElideRight
                        }
                        AeroButton {
                            text: "Select"
                            accent: modelData !== Pipewire.defaultAudioSource
                            enabled: modelData !== Pipewire.defaultAudioSource
                            onClicked: Pipewire.preferredDefaultAudioSource = modelData
                        }
                    }
                    Item {
                        id: sourceRow
                        width: parent.width
                        height: 34
                        readonly property int muteWidth: 148
                        AeroSlider {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(80, sourceRow.width - sourceRow.muteWidth - 12)
                            from: 0
                            to: 150
                            step: 1
                            value: modelData.audio ? Math.round(modelData.audio.volume * 100) : 0
                            onMoved: (v) => { if (modelData.audio) modelData.audio.volume = v / 100 }
                        }
                        AeroButton {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: sourceRow.muteWidth
                            text: modelData.audio && modelData.audio.muted ? "Muted" : "Live"
                            accent: !(modelData.audio && modelData.audio.muted)
                            onClicked: { if (modelData.audio) modelData.audio.muted = !modelData.audio.muted }
                        }
                    }
                }
            }
        }

        AeroCard {
            width: parent.width
            SectionLabel { text: "Applications"; width: parent.width }
            BodyText {
                width: parent.width
                visible: root.streams.length === 0
                text: "No application is playing audio."
            }
            Repeater {
                model: root.streams
                delegate: Column {
                    required property var modelData
                    width: parent.width
                    spacing: 6
                    Text {
                        width: parent.width
                        text: root.labelFor(modelData)
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: 620
                        elide: Text.ElideRight
                    }
                    Item {
                        id: streamRow
                        width: parent.width
                        height: 34
                        readonly property int muteWidth: 148
                        AeroSlider {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(80, streamRow.width - streamRow.muteWidth - 12)
                            from: 0
                            to: 150
                            step: 1
                            value: modelData.audio ? Math.round(modelData.audio.volume * 100) : 0
                            onMoved: (v) => { if (modelData.audio) modelData.audio.volume = v / 100 }
                        }
                        AeroButton {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: streamRow.muteWidth
                            text: modelData.audio && modelData.audio.muted ? "Muted" : "Sound"
                            accent: !(modelData.audio && modelData.audio.muted)
                            onClicked: { if (modelData.audio) modelData.audio.muted = !modelData.audio.muted }
                        }
                    }
                }
            }
        }
    }
}
