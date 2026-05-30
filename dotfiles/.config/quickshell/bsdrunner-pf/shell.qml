pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root

    ThemeLoader {
        id: themeLoader
    }

    readonly property var palette: themeLoader.palette
    property bool loading: false
    property bool runningAction: false
    property bool profileDirty: false
    property string statusTone: "info"
    property string statusMessage: "Loading firewall status..."
    property string actionDetails: ""
    property string snapshotStdoutText: ""
    property string snapshotStderrText: ""
    property int snapshotExitCode: 0
    property bool snapshotExited: false
    property bool snapshotStdoutFinished: false
    property bool snapshotStderrFinished: false
    property string actionStdoutText: ""
    property string actionStderrText: ""
    property int actionExitCode: 0
    property bool actionExited: false
    property bool actionStdoutFinished: false
    property bool actionStderrFinished: false
    property string activeActionId: ""
    property string activeActionArg1: ""
    property string activeActionArg2: ""
    property string activeActionLabel: ""
    property string pendingActionId: ""
    property string pendingActionLabel: ""
    property string pendingActionDescription: ""
    property string pfState: "unknown"
    property bool pfRunning: false
    property bool pfAvailable: true
    property bool pfBootEnabled: false
    property bool pflogBootEnabled: false
    property string configState: "unknown"
    property bool configManaged: false
    property bool configMatchesProfile: false
    property string configChecksum: ""
    property string lastResultTone: "info"
    property string lastResultMessage: "No firewall action has run yet."
    property string lastResultTimestamp: ""
    property var settings: ({
        "allow_outbound": true,
        "block_unsolicited": true,
        "allow_diagnostics": true,
        "allow_ipv6": true,
        "allow_dhcp": true,
        "allow_mdns": true,
        "allow_ssh_lan": false
    })
    property var rules: []

    function toneColor(tone) {
        switch (tone) {
        case "success":
            return palette.success
        case "warning":
            return palette.warning
        case "error":
            return palette.danger
        default:
            return palette.accent
        }
    }

    function pfStateLabel() {
        switch (pfState) {
        case "running":
            return "Protected"
        case "stopped":
            return "PF stopped"
        case "unloaded":
            return "PF not loaded"
        case "unavailable":
            return "PF unavailable"
        default:
            return "Unknown"
        }
    }

    function configStateLabel() {
        switch (configState) {
        case "managed":
            return "BSDRunner managed"
        case "external":
            return "External config detected"
        case "missing":
            return "No /etc/pf.conf"
        default:
            return "Unknown config"
        }
    }

    function settingValue(key) {
        return !!settings[key]
    }

    function toggleSetting(key, value) {
        if (runningAction || loading)
            return

        activeActionId = "set"
        activeActionArg1 = key
        activeActionArg2 = value ? "yes" : "no"
        activeActionLabel = "Updating setting"
        runActionProcess()
    }

    function requestAction(actionId, label, description) {
        if (runningAction)
            return

        pendingActionId = actionId
        pendingActionLabel = label
        pendingActionDescription = description
    }

    function clearPendingAction() {
        pendingActionId = ""
        pendingActionLabel = ""
        pendingActionDescription = ""
    }

    function confirmPendingAction() {
        if (!pendingActionId)
            return

        activeActionId = pendingActionId
        activeActionArg1 = ""
        activeActionArg2 = ""
        activeActionLabel = pendingActionLabel
        clearPendingAction()
        runActionProcess()
    }

    function runActionProcess() {
        runningAction = true
        actionDetails = ""
        statusTone = "info"
        statusMessage = activeActionLabel + "..."
        actionStdoutText = ""
        actionStderrText = ""
        actionExitCode = 0
        actionExited = false
        actionStdoutFinished = false
        actionStderrFinished = false
        actionProcess.running = true
    }

    function refreshSnapshot() {
        if (snapshotProcess.running)
            return

        loading = true
        snapshotStdoutText = ""
        snapshotStderrText = ""
        snapshotExitCode = 0
        snapshotExited = false
        snapshotStdoutFinished = false
        snapshotStderrFinished = false
        snapshotProcess.running = true
    }

    function maybeFinalizeSnapshot() {
        if (!snapshotExited || !snapshotStdoutFinished || !snapshotStderrFinished)
            return

        applySnapshot(snapshotStdoutText, snapshotExitCode, snapshotStderrText)
    }

    function maybeFinalizeAction() {
        if (!actionExited || !actionStdoutFinished || !actionStderrFinished)
            return

        applyActionResult(actionStdoutText, actionExitCode, actionStderrText)
    }

    function applySnapshot(text, exitCode, stderrText) {
        loading = false
        var payload = null

        try {
            payload = JSON.parse(text || "{}")
        } catch (error) {
            statusTone = "error"
            statusMessage = "The firewall backend returned invalid JSON."
            actionDetails = stderrText || text || ""
            return
        }

        if (exitCode !== 0 || !payload.ok) {
            statusTone = "error"
            statusMessage = payload.message || stderrText || "Unable to load firewall status."
            return
        }

        pfState = payload.pf ? payload.pf.state || "unknown" : "unknown"
        pfRunning = payload.pf ? !!payload.pf.running : false
        pfAvailable = payload.pf ? payload.pf.available !== false : true
        pfBootEnabled = payload.boot ? !!payload.boot.pf_enabled : false
        pflogBootEnabled = payload.boot ? !!payload.boot.pflog_enabled : false
        configState = payload.config ? payload.config.state || "unknown" : "unknown"
        configManaged = payload.config ? !!payload.config.managed : false
        configMatchesProfile = payload.config ? !!payload.config.matches_profile : false
        configChecksum = payload.config ? payload.config.checksum || "" : ""
        settings = payload.settings || settings
        rules = payload.rules || []
        profileDirty = configManaged && !configMatchesProfile
        lastResultTone = payload.last_result ? payload.last_result.tone || "info" : "info"
        lastResultMessage = payload.last_result ? payload.last_result.message || payload.message : payload.message
        lastResultTimestamp = payload.last_result ? payload.last_result.timestamp || "" : ""
        statusTone = configState === "external" ? "warning" : "info"
        statusMessage = configState === "external"
            ? "External /etc/pf.conf detected. Adopt the BSDRunner profile to let this GUI manage it."
            : payload.message || "Loaded firewall status."
    }

    function applyActionResult(text, exitCode, stderrText) {
        runningAction = false
        var payload = null

        try {
            payload = JSON.parse(text || "{}")
        } catch (error) {
            payload = null
        }

        if (payload && payload.ok && exitCode === 0) {
            statusTone = activeActionId === "disable" ? "warning" : "success"
            statusMessage = payload.message || "Firewall action completed."
            actionDetails = payload.details || ""
            if (activeActionId === "set")
                profileDirty = true
            if (activeActionId === "apply" || activeActionId === "adopt")
                profileDirty = false
        } else if (payload) {
            statusTone = "error"
            statusMessage = payload.message || "Firewall action failed."
            actionDetails = payload.details || stderrText || ""
        } else {
            statusTone = "error"
            statusMessage = "Firewall backend returned invalid JSON."
            actionDetails = stderrText || text || ""
        }

        activeActionId = ""
        activeActionArg1 = ""
        activeActionArg2 = ""
        activeActionLabel = ""
        refreshSnapshot()
    }

    Component.onCompleted: refreshSnapshot()

    Process {
        id: snapshotProcess
        property var controller: root

        command: [
            "sh",
            themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-pf-backend.sh",
            "snapshot"
        ]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                snapshotProcess.controller.snapshotStdoutText = text
                snapshotProcess.controller.snapshotStdoutFinished = true
                snapshotProcess.controller.maybeFinalizeSnapshot()
            }
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                snapshotProcess.controller.snapshotStderrText = text
                snapshotProcess.controller.snapshotStderrFinished = true
                snapshotProcess.controller.maybeFinalizeSnapshot()
            }
        }
        onExited: function(exitCode, exitStatus) {
            snapshotProcess.controller.snapshotExitCode = exitCode
            snapshotProcess.controller.snapshotExited = true
            snapshotProcess.controller.maybeFinalizeSnapshot()
        }
    }

    Process {
        id: actionProcess
        property var controller: root

        command: [
            "sh",
            themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-pf-backend.sh",
            root.activeActionId,
            root.activeActionArg1,
            root.activeActionArg2
        ]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                actionProcess.controller.actionStdoutText = text
                actionProcess.controller.actionStdoutFinished = true
                actionProcess.controller.maybeFinalizeAction()
            }
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                actionProcess.controller.actionStderrText = text
                actionProcess.controller.actionStderrFinished = true
                actionProcess.controller.maybeFinalizeAction()
            }
        }
        onExited: function(exitCode, exitStatus) {
            actionProcess.controller.actionExitCode = exitCode
            actionProcess.controller.actionExited = true
            actionProcess.controller.maybeFinalizeAction()
        }
    }

    Connections {
        target: Quickshell

        function onLastWindowClosed() {
            Qt.quit()
        }
    }

    FloatingWindow {
        visible: true
        title: "BSDRunner Firewall"
        minimumSize: Qt.size(1120, 700)
        maximumSize: Qt.size(1120, 700)
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: root.palette.panelBackground

            Column {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                Row {
                    width: parent.width
                    height: 96
                    spacing: 14

                    Rectangle {
                        width: 330
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.toneColor(root.pfRunning ? "success" : "warning")

                        Row {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 14

                            Rectangle {
                                width: 48
                                height: 48
                                radius: 24
                                y: 8
                                color: Qt.alpha(root.toneColor(root.pfRunning ? "success" : "warning"), 0.18)
                                border.width: 2
                                border.color: root.toneColor(root.pfRunning ? "success" : "warning")

                                Text {
                                    anchors.centerIn: parent
                                    text: root.pfRunning ? "OK" : "!"
                                    color: root.toneColor(root.pfRunning ? "success" : "warning")
                                    font.pixelSize: 24
                                    font.bold: true
                                }
                            }

                            Column {
                                width: parent.width - 70
                                spacing: 4

                                Text {
                                    width: parent.width
                                    text: root.pfStateLabel()
                                    color: root.palette.primaryText
                                    font.pixelSize: 28
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: "Desktop Protection"
                                    color: root.palette.secondaryText
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Text {
                                    width: parent.width
                                    text: root.configStateLabel()
                                    color: root.toneColor(root.configState === "external" ? "warning" : "info")
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 398
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.panelBorder

                        Row {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12

                            Repeater {
                                model: [
                                    { "label": "PF at boot", "value": root.pfBootEnabled ? "Enabled" : "Disabled", "tone": root.pfBootEnabled ? "success" : "warning" },
                                    { "label": "pflog", "value": root.pflogBootEnabled ? "Enabled" : "Disabled", "tone": root.pflogBootEnabled ? "success" : "warning" },
                                    { "label": "Profile", "value": root.configState === "external" ? "External" : (root.profileDirty ? "Pending" : "Current"), "tone": root.configState === "external" ? "warning" : (root.profileDirty ? "warning" : "info") }
                                ]

                                delegate: Rectangle {
                                    required property var modelData

                                    width: 116
                                    height: 64
                                    radius: 8
                                    color: root.palette.panelBackground
                                    border.width: 1
                                    border.color: root.toneColor(modelData.tone)

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 4

                                        Text {
                                            width: parent.width
                                            text: modelData.label
                                            color: root.palette.mutedText
                                            font.pixelSize: 11
                                            font.bold: true
                                        }

                                        Text {
                                            width: parent.width
                                            text: modelData.value
                                            color: root.toneColor(modelData.tone)
                                            font.pixelSize: 16
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width - 330 - 398 - 28
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.toneColor(root.statusTone)

                        Column {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 6

                            Text {
                                text: "Last Result"
                                color: root.palette.mutedText
                                font.pixelSize: 11
                                font.bold: true
                            }

                            Text {
                                width: parent.width
                                text: root.statusMessage
                                color: root.palette.primaryText
                                font.pixelSize: 14
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: 46
                    spacing: 10

                    Repeater {
                        model: [
                            { "id": "validate", "label": "Validate", "tone": "info", "text": "Validate the generated BSDRunner firewall profile before loading it." },
                            { "id": root.configState === "external" ? "adopt" : "apply", "label": root.configState === "external" ? "Adopt Profile" : "Apply Profile", "tone": root.configState === "external" ? "warning" : "success", "text": root.configState === "external" ? "Replace the external /etc/pf.conf with the BSDRunner managed profile." : "Validate, install, and reload the generated BSDRunner firewall profile." },
                            { "id": "reload", "label": "Reload", "tone": "info", "text": "Reload the current /etc/pf.conf ruleset." },
                            { "id": "enable", "label": "Enable at Boot", "tone": "success", "text": "Enable PF and pflog services and start them now." },
                            { "id": "disable", "label": "Disable PF Now", "tone": "warning", "text": "Immediately disable PF without deleting /etc/pf.conf." }
                        ]

                        delegate: Rectangle {
                            required property var modelData

                            width: 150
                            height: 42
                            radius: 8
                            color: actionMouse.containsMouse ? root.palette.cardHover : root.palette.cardBackground
                            opacity: root.runningAction ? 0.45 : 1.0
                            border.width: 2
                            border.color: root.toneColor(modelData.tone)

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: root.palette.primaryText
                                font.pixelSize: 13
                                font.bold: true
                            }

                            MouseArea {
                                id: actionMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !root.runningAction
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.requestAction(modelData.id, modelData.label, modelData.text)
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: parent.height - 96 - 46 - 28
                    spacing: 14

                    Rectangle {
                        width: 474
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.panelBorder

                        Column {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12

                            Text {
                                text: "Friendly Controls"
                                color: root.palette.primaryText
                                font.pixelSize: 22
                                font.bold: true
                            }

                            Repeater {
                                model: [
                                    { "key": "allow_outbound", "label": "Allow outbound connections", "detail": "Let apps on this laptop start connections." },
                                    { "key": "block_unsolicited", "label": "Block unsolicited inbound", "detail": "Reject connections this laptop did not start." },
                                    { "key": "allow_diagnostics", "label": "Allow ping and diagnostics", "detail": "Keep ping and useful network errors working." },
                                    { "key": "allow_ipv6", "label": "Allow IPv6 essentials", "detail": "Keep IPv6 neighbor discovery and MTU discovery working." },
                                    { "key": "allow_dhcp", "label": "Allow DHCP address setup", "detail": "Let the network assign addresses and routes." },
                                    { "key": "allow_mdns", "label": "Allow local discovery", "detail": "Find local printers, casting devices, and .local names." },
                                    { "key": "allow_ssh_lan", "label": "Allow SSH from local network", "detail": "Open port 22 only to private IPv4 LAN ranges." }
                                ]

                                delegate: Rectangle {
                                    id: toggleRow

                                    required property var modelData
                                    readonly property bool checked: root.settingValue(modelData.key)

                                    width: parent.width
                                    height: 54
                                    radius: 8
                                    color: toggleMouse.containsMouse ? root.palette.cardHover : root.palette.panelBackground
                                    border.width: 1
                                    border.color: checked ? root.palette.accent : root.palette.frameBorder

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 12

                                        Rectangle {
                                            width: 48
                                            height: 26
                                            radius: 13
                                            y: 4
                                            color: toggleRow.checked ? root.palette.accent : root.palette.frameBorder

                                            Rectangle {
                                                width: 20
                                                height: 20
                                                radius: 10
                                                x: toggleRow.checked ? 24 : 4
                                                y: 3
                                                color: toggleRow.checked ? root.palette.frameBackground : root.palette.mutedText
                                            }
                                        }

                                        Column {
                                            width: parent.width - 60
                                            spacing: 2

                                            Text {
                                                width: parent.width
                                                text: toggleRow.modelData.label
                                                color: root.palette.primaryText
                                                font.pixelSize: 14
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                width: parent.width
                                                text: toggleRow.modelData.detail
                                                color: root.palette.mutedText
                                                font.pixelSize: 11
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: toggleMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: !root.runningAction && !root.loading
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: root.toggleSetting(toggleRow.modelData.key, !toggleRow.checked)
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                text: root.configState === "external" ? "These controls edit the BSDRunner profile, but /etc/pf.conf is external until you adopt it." : (root.profileDirty ? "Changes are saved to the BSDRunner profile but are not active until Apply Profile succeeds." : "These controls describe the active BSDRunner profile.")
                                color: root.configState === "external" || root.profileDirty ? root.palette.warning : root.palette.mutedText
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width - 474 - 14
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.panelBorder

                        Column {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12

                            Text {
                                text: "Rules Overview"
                                color: root.palette.primaryText
                                font.pixelSize: 22
                                font.bold: true
                            }

                            Text {
                                width: parent.width
                                text: "The GUI keeps pf syntax out of the main workflow. These rows are the human version of the generated profile."
                                color: root.palette.mutedText
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }

                            Repeater {
                                model: root.rules

                                delegate: Rectangle {
                                    required property var modelData

                                    width: parent.width
                                    height: 58
                                    radius: 8
                                    color: root.palette.panelBackground
                                    border.width: 1
                                    border.color: modelData.enabled ? root.palette.success : root.palette.frameBorder

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 12

                                        Rectangle {
                                            width: 30
                                            height: 30
                                            radius: 15
                                            y: 2
                                            color: Qt.alpha(modelData.enabled ? root.palette.success : root.palette.frameBorder, 0.18)
                                            border.width: 1
                                            border.color: modelData.enabled ? root.palette.success : root.palette.frameBorder

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.enabled ? "ON" : "OFF"
                                                color: modelData.enabled ? root.palette.success : root.palette.mutedText
                                                font.pixelSize: 16
                                                font.bold: true
                                            }
                                        }

                                        Column {
                                            width: parent.width - 42
                                            spacing: 2

                                            Text {
                                                width: parent.width
                                                text: modelData.label
                                                color: root.palette.primaryText
                                                font.pixelSize: 14
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                width: parent.width
                                                text: modelData.description
                                                color: root.palette.secondaryText
                                                font.pixelSize: 11
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 84
                                radius: 8
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.toneColor(root.lastResultTone)

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 5

                                    Text {
                                        text: "Backend Detail"
                                        color: root.toneColor(root.lastResultTone)
                                        font.pixelSize: 12
                                        font.bold: true
                                    }

                                    Text {
                                        width: parent.width
                                        text: root.actionDetails.length > 0 ? root.actionDetails : root.lastResultMessage
                                        color: root.palette.secondaryText
                                        font.pixelSize: 11
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 3
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: root.pendingActionId.length > 0
                anchors.fill: parent
                color: Qt.alpha("#000000", 0.58)

                Rectangle {
                    width: 460
                    height: 226
                    radius: 8
                    anchors.centerIn: parent
                    color: root.palette.cardBackground
                    border.width: 2
                    border.color: root.toneColor(root.pendingActionId === "disable" || root.pendingActionId === "adopt" ? "warning" : "info")

                    Column {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 14

                        Text {
                            width: parent.width
                            text: root.pendingActionLabel
                            color: root.palette.primaryText
                            font.pixelSize: 22
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: root.pendingActionDescription
                            color: root.palette.secondaryText
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            width: parent.width
                            text: "This action can change live firewall behavior."
                            color: root.palette.warning
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }

                        Row {
                            width: parent.width
                            height: 42
                            spacing: 12

                            Rectangle {
                                width: 150
                                height: 40
                                radius: 8
                                color: root.palette.accent
                                border.width: 2
                                border.color: root.palette.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: "Confirm"
                                    color: root.palette.frameBackground
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.confirmPendingAction()
                                }
                            }

                            Rectangle {
                                width: 150
                                height: 40
                                radius: 8
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.frameBorder

                                Text {
                                    anchors.centerIn: parent
                                    text: "Cancel"
                                    color: root.palette.secondaryText
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.clearPendingAction()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
