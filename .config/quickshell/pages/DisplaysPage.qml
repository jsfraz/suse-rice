import QtQuick
import qs.components

Item {
    id: root
    property var monitors: []
    property var scales: [1, 1.25, 1.5, 1.75, 2]
    property var transforms: [
        { value: 0, label: "0°" },
        { value: 1, label: "90°" },
        { value: 2, label: "180°" },
        { value: 3, label: "270°" }
    ]
    property bool busy: false
    property string message: ""
    property bool followDarkman: true
    property bool sunsetOn: false
    property int temperature: 4000
    property bool sunsetBusy: false
    property bool sunsetLoaded: false
    property bool sunsetPending: false
    property string sunsetMessage: ""

    function script() { return Config.scripts + "/monitors.py" }

    function load(code, stdout, stderr) {
        busy = false
        var parsed = null
        try {
            parsed = JSON.parse(stdout)
        } catch (e) {
            message = (stderr || stdout || "Could not load displays").trim()
            return
        }
        if (!parsed.ok) {
            message = parsed.error || "Action failed"
            return
        }
        monitors = parsed.monitors || []
        if (parsed.scales)
            scales = parsed.scales
        if (parsed.transforms)
            transforms = parsed.transforms
        message = ""
    }

    function scaleIndex(scale) {
        var best = 0
        var bestDiff = 999
        for (var i = 0; i < scales.length; i++) {
            var diff = Math.abs(scales[i] - scale)
            if (diff < bestDiff) {
                best = i
                bestDiff = diff
            }
        }
        return best
    }

    function transformIndex(value) {
        for (var i = 0; i < transforms.length; i++) {
            if (transforms[i].value === value)
                return i
        }
        return 0
    }

    function scaleLabels() {
        var out = []
        for (var i = 0; i < scales.length; i++)
            out.push((scales[i] * 100) + " %")
        return out
    }

    function transformLabels() {
        var out = []
        for (var i = 0; i < transforms.length; i++)
            out.push(transforms[i].label)
        return out
    }

    function apply() {
        busy = true
        statusProc.run(["python3", script(), "apply", JSON.stringify({ monitors: monitors })])
    }

    function sunsetScript() { return Config.scripts + "/sunset.py" }

    function commitSunset() {
        if (!sunsetLoaded)
            return
        if (sunsetBusy) {
            sunsetPending = true
            return
        }
        sunsetBusy = true
        sunsetPending = false
        sunsetMessage = ""
        sunsetProc.run(["python3", sunsetScript(), "apply", JSON.stringify({
            followDarkman: followDarkman,
            on: sunsetOn,
            temperature: temperature
        })])
    }

    function takeSunset(stdout, stderr) {
        sunsetBusy = false
        var parsed = null
        try {
            parsed = JSON.parse(stdout)
        } catch (e) {
            sunsetMessage = (stderr || stdout || "Could not load the filter").trim()
            if (sunsetPending)
                commitSunset()
            return
        }
        if (!parsed.ok) {
            sunsetMessage = parsed.error || "Could not save the filter"
            sunsetPending = false
            return
        }
        if (sunsetPending) {
            commitSunset()
            return
        }
        followDarkman = parsed.followDarkman === true
        sunsetOn = parsed.on === true
        temperature = parsed.temperature
        sunsetLoaded = true
        sunsetMessage = ""
    }

    Component.onCompleted: {
        statusProc.run(["python3", script(), "status"])
        sunsetProc.run(["python3", sunsetScript(), "status"])
    }

    Proc {
        id: statusProc
        onFinished: (code, stdout, stderr) => root.load(code, stdout, stderr)
    }

    Proc {
        id: sunsetProc
        onFinished: (code, stdout, stderr) => root.takeSunset(stdout, stderr)
    }

    Page {
        anchors.fill: parent
        anchors.rightMargin: 12
        heading: "Displays"

        BodyText {
            width: parent.width
            text: root.message
            visible: root.message.length > 0
        }

        AeroCard {
            width: parent.width
            SectionLabel { text: "Blue light filter"; width: parent.width }
            Row {
                width: parent.width
                spacing: 12
                BodyText {
                    width: parent.width - 80
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Automatic"
                }
                AeroSwitch {
                    checked: root.followDarkman
                    onClicked: {
                        root.followDarkman = !root.followDarkman
                        root.commitSunset()
                    }
                }
            }
            Row {
                width: parent.width
                spacing: 12
                opacity: root.followDarkman ? 0.4 : 1
                BodyText {
                    width: parent.width - 80
                    anchors.verticalCenter: parent.verticalCenter
                    text: "On"
                }
                AeroSwitch {
                    enabled: !root.followDarkman
                    checked: root.sunsetOn
                    onClicked: {
                        root.sunsetOn = !root.sunsetOn
                        root.commitSunset()
                    }
                }
            }
            BodyText { text: "Temperature  ·  " + root.temperature + " K" }
            AeroSlider {
                width: parent.width
                from: 2500
                to: 6500
                step: 100
                value: root.temperature
                onMoved: (v) => {
                    root.temperature = v
                    root.commitSunset()
                }
            }
            BodyText {
                width: parent.width
                text: root.sunsetMessage
                visible: root.sunsetMessage.length > 0
            }
        }

        Repeater {
            model: root.monitors
            delegate: AeroCard {
                required property int index
                required property var modelData
                property int monitorIndex: index
                width: parent.width
                SectionLabel { text: modelData.name; width: parent.width }
                BodyText { width: parent.width; text: modelData.description || "" }

                Row {
                    width: parent.width
                    BodyText {
                        width: parent.width - 80
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Enabled"
                    }
                    AeroSwitch {
                        checked: modelData.enabled === true
                        onClicked: {
                            var copy = root.monitors.slice()
                            var item = Object.assign({}, copy[index])
                            item.enabled = !item.enabled
                            copy[index] = item
                            root.monitors = copy
                        }
                    }
                }

                BodyText { text: "Resolution"; visible: modelData.enabled === true }
                AeroCombo {
                    width: parent.width
                    visible: modelData.enabled === true
                    labels: modelData.modes || []
                    currentIndex: Math.max(0, (modelData.modes || []).indexOf(modelData.mode))
                    onPicked: (choice) => {
                        var modes = modelData.modes || []
                        if (choice < 0 || choice >= modes.length)
                            return
                        var copy = root.monitors.slice()
                        var item = Object.assign({}, copy[monitorIndex])
                        item.mode = modes[choice]
                        copy[monitorIndex] = item
                        root.monitors = copy
                    }
                }

                BodyText { text: "Scale"; visible: modelData.enabled === true }
                AeroCombo {
                    width: parent.width
                    visible: modelData.enabled === true
                    labels: root.scaleLabels()
                    currentIndex: root.scaleIndex(modelData.scale)
                    onPicked: (choice) => {
                        if (choice < 0 || choice >= root.scales.length)
                            return
                        var copy = root.monitors.slice()
                        var item = Object.assign({}, copy[monitorIndex])
                        item.scale = root.scales[choice]
                        copy[monitorIndex] = item
                        root.monitors = copy
                    }
                }

                BodyText { text: "Rotation"; visible: modelData.enabled === true }
                AeroCombo {
                    width: parent.width
                    visible: modelData.enabled === true
                    labels: root.transformLabels()
                    currentIndex: root.transformIndex(modelData.transform)
                    onPicked: (choice) => {
                        if (choice < 0 || choice >= root.transforms.length)
                            return
                        var copy = root.monitors.slice()
                        var item = Object.assign({}, copy[monitorIndex])
                        item.transform = root.transforms[choice].value
                        copy[monitorIndex] = item
                        root.monitors = copy
                    }
                }

                Row {
                    width: parent.width
                    spacing: 10
                    visible: modelData.enabled === true
                    Column {
                        width: (parent.width - 10) / 2
                        spacing: 4
                        BodyText { text: "Position X" }
                        AeroField {
                            width: parent.width
                            text: String(modelData.x)
                            onTextChanged: {
                                var copy = root.monitors.slice()
                                var item = Object.assign({}, copy[monitorIndex])
                                item.x = parseInt(text, 10) || 0
                                copy[monitorIndex] = item
                                if (item.x !== root.monitors[monitorIndex].x)
                                    root.monitors = copy
                            }
                        }
                    }
                    Column {
                        width: (parent.width - 10) / 2
                        spacing: 4
                        BodyText { text: "Position Y" }
                        AeroField {
                            width: parent.width
                            text: String(modelData.y)
                            onTextChanged: {
                                var copy = root.monitors.slice()
                                var item = Object.assign({}, copy[monitorIndex])
                                item.y = parseInt(text, 10) || 0
                                copy[monitorIndex] = item
                                if (item.y !== root.monitors[monitorIndex].y)
                                    root.monitors = copy
                            }
                        }
                    }
                }
            }
        }

        Row {
            spacing: 10
            AeroButton {
                text: root.busy ? "Saving…" : "Apply"
                enabled: !root.busy && root.monitors.length > 0
                onClicked: root.apply()
            }
            AeroButton {
                text: "Default"
                accent: false
                enabled: !root.busy
                onClicked: {
                    root.busy = true
                    statusProc.run(["python3", root.script(), "reset"])
                }
            }
        }
        BodyText {
            width: parent.width
            text: "Default restores Hyprland's preferred mode and stops saving a custom layout."
        }
    }
}
