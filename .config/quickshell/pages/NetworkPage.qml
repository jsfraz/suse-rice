import QtQuick
import Quickshell
import qs.components

Item {
    id: root

    property var snapshot: ({
        wifiEnabled: false,
        networks: [],
        saved: [],
        vpn: [],
        ethernet: [],
        openvpnReady: false,
        openvpnEditorReady: false
    })
    property bool editorChecked: false
    property bool editorReady: false
    property bool firewallChecked: false
    property bool firewallReady: false
    readonly property var activeSaved: {
        var saved = snapshot.saved || []
        var vpn = snapshot.vpn || []
        var out = []
        for (var i = 0; i < saved.length; ++i) {
            if (saved[i] && saved[i].active)
                out.push(saved[i])
        }
        for (var j = 0; j < vpn.length; ++j) {
            if (vpn[j] && vpn[j].active)
                out.push(vpn[j])
        }
        return out
    }

    function savedWifiName(ssid) {
        var saved = snapshot.saved || []
        for (var i = 0; i < saved.length; ++i) {
            var item = saved[i]
            if (!item || item.type !== "wifi")
                continue
            if (item.ssid === ssid || item.name === ssid)
                return item.name
        }
        return ""
    }

    function isEnterprise(security) {
        if (!security)
            return false
        return security.indexOf("802.1X") !== -1 || security.indexOf("802.1x") !== -1
    }

    function openEditor() {
        if (!editorReady)
            return
        Quickshell.execDetached(["nm-connection-editor"])
        Config.dismissSettings()
    }

    function openFirewall() {
        if (!firewallReady)
            return
        Quickshell.execDetached(["firewall-config"])
        Config.dismissSettings()
    }
    property bool busy: false
    property bool scanning: false
    property string pendingSsid: ""
    property string pendingVpnName: ""
    property bool pickingVpn: false
    // Last nm.py action: drives error notification title (VPN vs Network).
    property bool notifyVpn: false
    property bool silentRefresh: false

    function script() { return Config.scripts + "/nm.py" }

    function notifyFailure(message) {
        Config.notifyError(message, root.notifyVpn ? "VPN" : "Network")
    }

    function connectionTypeLabel(type) {
        if (type === "wifi")
            return "Wi-Fi"
        if (type === "vpn")
            return "VPN"
        return "Ethernet"
    }

    function pickVpnFile() {
        if (!snapshot.openvpnReady)
            return
        pickingVpn = true
        vpnPickerProc.run([
            "zenity", "--file-selection", "--title=Import VPN",
            "--file-filter=OpenVPN | *.ovpn"
        ])
    }

    function connectVpn(name, needsLogin) {
        pendingVpnName = name
        notifyVpn = true
        if (needsLogin) {
            vpnUserField.text = ""
            vpnPasswordField.text = ""
            vpnAuthDialog.visible = true
            return
        }
        busy = true
        proc.run(["python3", script(), "up", name])
    }

    function take(code, stdout, stderr) {
        busy = false
        scanning = false
        var quiet = root.silentRefresh
        root.silentRefresh = false
        var parsed = null
        try {
            parsed = JSON.parse(stdout)
        } catch (e) {
            if (!quiet)
                notifyFailure((stderr || stdout || "The network did not respond").trim())
            return
        }
        if (!parsed.ok) {
            var err = parsed.error || "Action failed"
            if (!quiet)
                notifyFailure(err)
            if (parsed.needsAuth) {
                notifyVpn = true
                pendingVpnName = parsed.connection || pendingVpnName
                vpnUserField.text = ""
                vpnPasswordField.text = ""
                vpnAuthDialog.visible = true
                return
            }
            return
        }
        notifyVpn = false
        snapshot = parsed
    }

    function refresh() {
        if (busy)
            return
        notifyVpn = false
        silentRefresh = true
        busy = true
        proc.run(["python3", script(), "status"])
    }

    function scan() {
        notifyVpn = false
        busy = true
        scanning = true
        proc.run(["python3", script(), "scan"])
    }

    Component.onCompleted: {
        editorProc.run(["sh", "-c", "command -v nm-connection-editor"])
        firewallProc.run(["sh", "-c", "command -v firewall-config"])
    }

    Timer {
        id: refreshDebounce
        interval: 80
        onTriggered: root.refresh()
    }

    Connections {
        target: Config.settingsWindow
        function onVisibleChanged() {
            if (Config.settingsWindow && Config.settingsWindow.visible)
                refreshDebounce.restart()
        }
    }

    Proc {
        id: proc
        onFinished: (code, stdout, stderr) => root.take(code, stdout, stderr)
    }

    Proc {
        id: editorProc
        onFinished: (code, stdout) => {
            root.editorChecked = true
            root.editorReady = code === 0 && stdout.trim().length > 0
        }
    }

    Proc {
        id: firewallProc
        onFinished: (code, stdout) => {
            root.firewallChecked = true
            root.firewallReady = code === 0 && stdout.trim().length > 0
        }
    }

    Proc {
        id: vpnPickerProc
        onFinished: (code, stdout, stderr) => {
            root.pickingVpn = false
            if (code === 0) {
                var path = stdout.trim()
                if (path.startsWith("file://"))
                    path = decodeURIComponent(path.slice(7))
                if (path.length > 0) {
                    root.notifyVpn = true
                    root.busy = true
                    proc.run(["python3", root.script(), "import-vpn", path])
                }
                return
            }
            if (code !== 1)
                Config.notifyError((stderr || "Could not start Zenity").trim(), "VPN")
        }
    }

    Page {
        anchors.fill: parent
        anchors.rightMargin: 12
        heading: "Network"

        AeroCard {
            width: parent.width
            Item {
                width: parent.width
                height: 32

                SectionLabel {
                    id: wifiLabel
                    text: "Wi-Fi"
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    id: refreshButton
                    width: 28
                    height: 28
                    anchors.left: wifiLabel.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: !root.busy && root.snapshot.wifiEnabled === true
                    opacity: enabled ? 1 : 0.45
                    scale: refreshMouse.pressed && enabled ? 0.94 : 1

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: refreshMouse.pressed && refreshButton.enabled ? 2 : 0
                        radius: height / 2
                        border.width: 1
                        border.color: Theme.line
                        gradient: Gradient {
                            GradientStop { position: 0; color: Theme.sheen(refreshMouse.pressed ? 0.22 : 0.62) }
                            GradientStop { position: 0.46; color: refreshMouse.pressed ? Theme.gelDeep : Theme.gloss(Theme.gel) }
                            GradientStop { position: 0.52; color: Theme.glassDeep }
                            GradientStop { position: 1; color: Theme.glassDeep }
                        }
                        AeroSheen { strength: refreshMouse.pressed ? 0.25 : 0.75 }
                    }

                    Item {
                        id: refreshGlyph
                        anchors.centerIn: parent
                        width: 20
                        height: 20

                        NumberAnimation {
                            target: refreshGlyph
                            property: "rotation"
                            running: root.scanning
                            from: 0
                            to: 360
                            duration: 700
                            loops: Animation.Infinite
                            onRunningChanged: if (!running) refreshGlyph.rotation = 0
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "\uf021"
                            color: Theme.ink
                            font.family: "Font Awesome 7 Free Solid"
                            font.pixelSize: 14
                            font.weight: 900
                        }
                    }

                    MouseArea {
                        id: refreshMouse
                        anchors.fill: parent
                        enabled: refreshButton.enabled
                        onClicked: root.scan()
                    }
                }

                Row {
                    id: switchRow
                    spacing: 8
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    BodyText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.snapshot.wifiEnabled ? "On" : "Off"
                    }
                    AeroSwitch {
                        checked: root.snapshot.wifiEnabled === true
                        enabled: !root.busy
                        onClicked: {
                            root.busy = true
                            proc.run(["python3", root.script(), "radio", root.snapshot.wifiEnabled ? "off" : "on"])
                        }
                    }
                }
            }
        }

        AeroCard {
            width: parent.width
            visible: root.snapshot.wifiEnabled === true
            SectionLabel { text: "Networks in range"; width: parent.width }
            BodyText {
                width: parent.width
                visible: !root.snapshot.networks || root.snapshot.networks.length === 0
                text: "No network. Try searching again."
            }
            Repeater {
                model: root.snapshot.networks || []
                delegate: Row {
                    required property var modelData
                    width: parent.width
                    spacing: 10
                    Column {
                        width: parent.width - 130
                        spacing: 2
                        Text {
                            width: parent.width
                            text: modelData.ssid + (modelData.inUse ? "  ·  connected" : "")
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.weight: 640
                            elide: Text.ElideRight
                        }
                        BodyText {
                            width: parent.width
                            text: modelData.signal + " %  ·  " + (modelData.security || "open")
                        }
                    }
                    AeroButton {
                        text: modelData.inUse ? "Connected" : "Connect"
                        enabled: !modelData.inUse && !root.busy
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            var open = !modelData.security || modelData.security === "--"
                            var known = root.savedWifiName(modelData.ssid)
                            if (root.isEnterprise(modelData.security) && !known) {
                                Config.notifyInfo("802.1X networks need a profile from geteduroam before you can connect here.", "Network")
                                return
                            }
                            if (open || known) {
                                root.busy = true
                                proc.run(["python3", root.script(), "connect", modelData.ssid])
                            } else {
                                root.pendingSsid = modelData.ssid
                                passwordField.text = ""
                                passwordDialog.visible = true
                            }
                        }
                    }
                }
            }
        }

        AeroCard {
            width: parent.width
            SectionLabel { text: "Active connections"; width: parent.width }
            BodyText {
                width: parent.width
                visible: root.activeSaved.length === 0
                text: "No active connection."
            }
            Repeater {
                model: root.activeSaved
                delegate: Row {
                    required property var modelData
                    width: parent.width
                    spacing: 8
                    Column {
                        width: parent.width - 280
                        Text {
                            width: parent.width
                            text: modelData.name
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.weight: 620
                            elide: Text.ElideRight
                        }
                        BodyText {
                            text: root.connectionTypeLabel(modelData.type)
                        }
                    }
                    AeroButton {
                        text: "Disconnect"
                        accent: false
                        enabled: !root.busy
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            root.busy = true
                            proc.run(["python3", root.script(), "down", modelData.name])
                        }
                    }
                    AeroButton {
                        text: "Forget"
                        accent: false
                        enabled: !root.busy
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            root.busy = true
                            proc.run(["python3", root.script(), "forget", modelData.name])
                        }
                    }
                }
            }
        }

        AeroCard {
            width: parent.width
            SectionLabel { text: "VPN"; width: parent.width }
            BodyText {
                width: parent.width
                visible: !root.snapshot.vpn || root.snapshot.vpn.length === 0
                text: "No VPN profiles yet."
            }
            Repeater {
                model: root.snapshot.vpn || []
                delegate: Row {
                    required property var modelData
                    width: parent.width
                    spacing: 8
                    Column {
                        width: parent.width - 280
                        spacing: 2
                        Text {
                            width: parent.width
                            text: modelData.name + (modelData.active ? "  ·  connected" : "")
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.weight: 620
                            elide: Text.ElideRight
                        }
                        BodyText {
                            text: (modelData.vpnType || "vpn")
                                + (modelData.systemWide ? "  ·  system" : "")
                                + (modelData.needsLogin ? "  ·  login" : "")
                        }
                    }
                    AeroButton {
                        text: "Copy to user"
                        accent: false
                        visible: modelData.systemWide === true
                        enabled: !root.busy
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            root.notifyVpn = true
                            root.busy = true
                            proc.run(["python3", root.script(), "rehome-vpn", modelData.name])
                        }
                    }
                    AeroButton {
                        text: modelData.active ? "Connected" : "Connect"
                        enabled: !modelData.active && !root.busy
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: root.connectVpn(modelData.name, modelData.needsLogin === true)
                    }
                    AeroButton {
                        text: "Disconnect"
                        accent: false
                        visible: modelData.active
                        enabled: !root.busy
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            root.busy = true
                            proc.run(["python3", root.script(), "down", modelData.name])
                        }
                    }
                    AeroButton {
                        text: "Remove"
                        accent: false
                        enabled: !root.busy
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            root.busy = true
                            proc.run(["python3", root.script(), "forget", modelData.name])
                        }
                    }
                }
            }
            AeroButton {
                text: "Import VPN…"
                enabled: root.snapshot.openvpnReady === true && !root.busy && !root.pickingVpn
                onClicked: root.pickVpnFile()
            }
            BodyText {
                width: parent.width
                visible: root.snapshot.openvpnReady !== true
                text: "OpenVPN import is not installed."
            }
        }

        AeroCard {
            width: parent.width
            SectionLabel { text: "Ethernet"; width: parent.width }
            BodyText {
                width: parent.width
                visible: !root.snapshot.ethernet || root.snapshot.ethernet.length === 0
                text: "No Ethernet adapter."
            }
            Repeater {
                model: root.snapshot.ethernet || []
                delegate: BodyText {
                    required property var modelData
                    width: parent.width
                    text: modelData.device + "  ·  " + modelData.state + (modelData.connection ? "  ·  " + modelData.connection : "")
                }
            }
        }

        AeroButton {
            text: "Settings"
            enabled: root.editorReady
            onClicked: root.openEditor()
        }

        BodyText {
            width: parent.width
            visible: root.editorChecked && !root.editorReady
            text: "Advanced network settings are not installed. Install them with: sudo zypper in NetworkManager-connection-editor"
        }

        BodyText {
            width: parent.width
            visible: root.snapshot.openvpnReady === true
                && root.snapshot.openvpnEditorReady !== true
            text: "The VPN tab in Settings stays empty until you install: sudo zypper in NetworkManager-applet-openvpn"
        }

        AeroCard {
            width: parent.width
            SectionLabel { text: "Firewall"; width: parent.width }
            BodyText {
                width: parent.width
                text: "Zones, services and ports are configured in firewall-config."
            }
        }

        AeroButton {
            text: "Firewall"
            enabled: root.firewallReady
            onClicked: root.openFirewall()
        }

        BodyText {
            width: parent.width
            visible: root.firewallChecked && !root.firewallReady
            text: "The firewall editor is not installed."
        }
    }

    Rectangle {
        id: vpnAuthDialog
        visible: false
        anchors.fill: parent
        color: Theme.tint(Theme.glassDeep, 0.45)
        radius: Theme.radius

        AeroCard {
            width: 420
            anchors.centerIn: parent
            SectionLabel {
                text: "Sign in to " + root.pendingVpnName
                width: parent.width
                wrapMode: Text.WordWrap
            }
            AeroField {
                id: vpnUserField
                width: parent.width
                placeholder: "Username"
            }
            AeroField {
                id: vpnPasswordField
                width: parent.width
                placeholder: "Password"
                password: true
                onAccepted: vpnAuthDialog.connectNow()
            }
            Row {
                spacing: 10
                AeroButton {
                    text: "Connect"
                    enabled: !root.busy
                    onClicked: vpnAuthDialog.connectNow()
                }
                AeroButton {
                    text: "Cancel"
                    accent: false
                    onClicked: vpnAuthDialog.visible = false
                }
            }
        }

        function connectNow() {
            vpnAuthDialog.visible = false
            root.notifyVpn = true
            root.busy = true
            proc.run([
                "python3", root.script(), "up", root.pendingVpnName,
                vpnUserField.text, vpnPasswordField.text
            ])
        }
    }

    Rectangle {
        id: passwordDialog
        visible: false
        anchors.fill: parent
        color: Theme.tint(Theme.glassDeep, 0.45)
        radius: Theme.radius

        AeroCard {
            width: 420
            anchors.centerIn: parent
            SectionLabel { text: "Password for " + root.pendingSsid; width: parent.width; wrapMode: Text.WordWrap }
            AeroField {
                id: passwordField
                width: parent.width
                placeholder: "Password"
                password: true
                onAccepted: passwordDialog.connectNow()
            }
            Row {
                spacing: 10
                AeroButton {
                    text: "Connect"
                    enabled: !root.busy
                    onClicked: passwordDialog.connectNow()
                }
                AeroButton {
                    text: "Cancel"
                    accent: false
                    onClicked: passwordDialog.visible = false
                }
            }
        }

        function connectNow() {
            passwordDialog.visible = false
            root.busy = true
            proc.run(["python3", root.script(), "connect", root.pendingSsid, passwordField.text])
        }
    }
}
