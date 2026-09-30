import QtQuick
import qs.components

Item {
    id: root
    property string layout: "cz"
    property string variant: ""
    property var layouts: []
    property var variants: []
    property bool busy: false
    property string message: ""

    function script() { return Config.scripts + "/keyboard.py" }

    function failText(stdout, stderr) {
        try {
            var parsed = JSON.parse(stdout)
            return parsed.error || "Action failed"
        } catch (e) {
            return (stderr || stdout || "Could not load the keyboard").trim()
        }
    }

    function shownLayouts() {
        var out = layouts.slice()
        if (layout && out.indexOf(layout) < 0)
            out.unshift(layout)
        return out
    }

    function variantLabels() {
        var out = ["none"]
        for (var i = 0; i < variants.length; i++)
            out.push(variants[i])
        return out
    }

    Component.onCompleted: {
        statusProc.run(["python3", script(), "status"])
        layoutProc.run(["python3", script(), "layouts"])
    }

    onLayoutChanged: variantProc.run(["python3", script(), "variants", layout])

    Proc {
        id: statusProc
        onFinished: (code, stdout, stderr) => {
            try {
                var parsed = JSON.parse(stdout)
                if (!parsed.ok) {
                    root.message = parsed.error
                    return
                }
                var same = root.layout === parsed.layout
                root.layout = parsed.layout
                root.variant = parsed.variant
                if (same)
                    variantProc.run(["python3", root.script(), "variants", root.layout])
            } catch (e) {
                root.message = root.failText(stdout, stderr)
            }
        }
    }

    Proc {
        id: layoutProc
        onFinished: (code, stdout, stderr) => {
            try {
                var parsed = JSON.parse(stdout)
                if (parsed.ok)
                    root.layouts = parsed.layouts
                else
                    root.message = parsed.error
            } catch (e) {
                root.message = root.failText(stdout, stderr)
            }
        }
    }

    Proc {
        id: variantProc
        onFinished: (code, stdout, stderr) => {
            try {
                var parsed = JSON.parse(stdout)
                if (parsed.ok)
                    root.variants = parsed.variants
            } catch (e) {
                root.variants = []
            }
        }
    }

    Proc {
        id: applyProc
        onFinished: (code, stdout, stderr) => {
            root.busy = false
            try {
                var parsed = JSON.parse(stdout)
                root.message = parsed.ok ? "Layout is set." : (parsed.error || "Action failed")
            } catch (e) {
                root.message = root.failText(stdout, stderr)
            }
        }
    }

    Page {
        anchors.fill: parent
        anchors.rightMargin: 12
        heading: "Keyboard"

        AeroCard {
            width: parent.width
            SectionLabel { text: "Layout"; width: parent.width }
            AeroCombo {
                width: parent.width
                labels: root.shownLayouts()
                currentIndex: Math.max(0, root.shownLayouts().indexOf(root.layout))
                onPicked: (choice) => {
                    var names = root.shownLayouts()
                    if (choice < 0 || choice >= names.length)
                        return
                    if (root.layout !== names[choice])
                        root.variant = ""
                    root.layout = names[choice]
                }
            }
        }

        AeroCard {
            width: parent.width
            SectionLabel { text: "Variant"; width: parent.width }
            AeroCombo {
                width: parent.width
                labels: root.variantLabels()
                currentIndex: root.variant === "" ? 0 : Math.max(0, root.variants.indexOf(root.variant) + 1)
                onPicked: (choice) => {
                    root.variant = choice <= 0 ? "" : (root.variants[choice - 1] || "")
                }
            }
        }

        Row {
            spacing: 10
            AeroButton {
                text: root.busy ? "Saving…" : "Apply"
                enabled: !root.busy
                onClicked: {
                    root.busy = true
                    applyProc.run(["python3", root.script(), "apply", root.layout, root.variant])
                }
            }
            AeroButton {
                text: "Restart wayvnc"
                accent: false
                enabled: !root.busy
                onClicked: {
                    root.busy = true
                    applyProc.run(["python3", root.script(), "restart-wayvnc"])
                }
            }
        }
        BodyText { width: parent.width; text: root.message; visible: root.message.length > 0 }
    }
}
