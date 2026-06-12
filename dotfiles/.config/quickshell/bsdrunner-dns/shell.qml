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
    property string statusTone: "info"
    property string statusMessage: "Loading DNS cache status..."
    property string actionDetails: ""
    property string activeActionId: ""
    property string activeActionArg: ""
    property string activeActionLabel: ""
    property string pendingActionId: ""
    property string pendingActionLabel: ""
    property string pendingActionDescription: ""
    property string lookupName: "freebsd.org"
    property string serviceState: "unknown"
    property bool serviceRunning: false
    property bool serviceAvailable: true
    property bool bootEnabled: false
    property bool localResolverActive: false
    property bool encryptedForwarding: false
    property bool caBundleAvailable: false
    property string caBundlePath: ""
    property string searchDomain: ""
    property var nameservers: []
    property var forwarders: []
    property bool hasDrill: false
    property bool hasSetup: false
    property bool hasControl: false
    property string lastResultTone: "info"
    property string lastResultMessage: "No DNS action has run yet."
    property string lastResultTimestamp: ""
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

    function headline() {
        if (!serviceAvailable)
            return "Unavailable"
        if (serviceRunning && localResolverActive)
            return "Cache Active"
        if (serviceRunning)
            return "Running"
        return "Cache Off"
    }

    function headlineTone() {
        if (serviceRunning && localResolverActive)
            return "success"
        if (serviceRunning || bootEnabled)
            return "warning"
        return "info"
    }

    function badgeText() {
        return headlineTone() === "success" ? "DNS" : "!"
    }

    function compactTimestamp(value) {
        if (!value || value.length === 0)
            return ""
        var parts = value.split(" ")
        if (parts.length >= 2)
            return parts[1].replace(/:[0-9][0-9]$/, "")
        return value
    }

    function firstNonEmptyLine(value) {
        if (!value || value.length === 0)
            return ""
        var lines = value.split("\n")
        for (var i = 0; i < lines.length; i += 1) {
            var line = lines[i].replace(/^\s+|\s+$/g, "")
            if (line.length > 0)
                return line
        }
        return ""
    }

    function statusDetailText() {
        if ((statusTone === "error" || lastResultTone === "error") && actionDetails.length > 0)
            return firstNonEmptyLine(actionDetails)
        if (lastResultTimestamp.length > 0)
            return "Updated " + compactTimestamp(lastResultTimestamp)
        return ""
    }

    function nameserverText() {
        if (!nameservers || nameservers.length === 0)
            return "No nameservers found"
        return nameservers.join("\n")
    }

    function forwarderZoneLabel(zone) {
        if (zone === ".")
            return "All other DNS"
        return zone || "Unknown"
    }

    function forwarderTargets(forwarder) {
        var targets = forwarder ? forwarder.targets || [] : []
        return targets.length > 0 ? targets : ["No targets"]
    }

    function requestAction(actionId, label, description) {
        if (runningAction || !actionAvailable(actionId))
            return
        pendingActionId = actionId
        pendingActionLabel = label
        pendingActionDescription = description
    }

    function actionAvailable(actionId) {
        var cacheEnabled = serviceRunning || bootEnabled
        switch (actionId) {
        case "enable":
            return !cacheEnabled
        case "disable":
            return cacheEnabled
        case "enable_dot":
            return !encryptedForwarding
        case "disable_dot":
            return encryptedForwarding
        default:
            return true
        }
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
        activeActionArg = ""
        activeActionLabel = pendingActionLabel
        clearPendingAction()
        runActionProcess()
    }

    function runLookup() {
        if (runningAction)
            return
        activeActionId = "test"
        activeActionArg = lookupName
        activeActionLabel = "Testing lookup"
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
            statusMessage = "The DNS backend returned invalid JSON."
            actionDetails = stderrText || text || ""
            return
        }

        if (exitCode !== 0 || !payload.ok) {
            statusTone = "error"
            statusMessage = payload.message || stderrText || "Unable to load DNS status."
            return
        }

        serviceState = payload.service ? payload.service.state || "unknown" : "unknown"
        serviceRunning = payload.service ? !!payload.service.running : false
        serviceAvailable = payload.service ? payload.service.available !== false : true
        bootEnabled = payload.boot ? !!payload.boot.enabled : false
        localResolverActive = payload.resolver ? !!payload.resolver.local_active : false
        encryptedForwarding = payload.resolver ? !!payload.resolver.encrypted_forwarding : false
        caBundleAvailable = payload.resolver ? !!payload.resolver.ca_bundle_available : false
        caBundlePath = payload.resolver ? payload.resolver.ca_bundle || "" : ""
        searchDomain = payload.resolver ? payload.resolver.search || "" : ""
        nameservers = payload.resolver ? payload.resolver.nameservers || [] : []
        forwarders = payload.resolver ? payload.resolver.forwarders || [] : []
        hasDrill = payload.tools ? !!payload.tools.drill : false
        hasSetup = payload.tools ? !!payload.tools.local_unbound_setup : false
        hasControl = payload.tools ? !!payload.tools.local_unbound_control : false
        lastResultTone = payload.last_result ? payload.last_result.tone || "info" : "info"
        lastResultMessage = payload.last_result ? payload.last_result.message || payload.message : payload.message
        lastResultTimestamp = payload.last_result ? payload.last_result.timestamp || "" : ""
        statusTone = lastResultTone
        statusMessage = payload.message || "Loaded DNS cache status."
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
            statusTone = activeActionId === "disable" || activeActionId === "disable_dot" ? "warning" : "success"
            statusMessage = payload.message || "DNS action completed."
            actionDetails = payload.details || ""
        } else if (payload) {
            statusTone = "error"
            statusMessage = payload.message || "DNS action failed."
            actionDetails = payload.details || stderrText || ""
        } else {
            statusTone = "error"
            statusMessage = "The DNS backend returned invalid JSON."
            actionDetails = stderrText || text || ""
        }

        activeActionId = ""
        activeActionArg = ""
        activeActionLabel = ""
        refreshSnapshot()
    }

    Component.onCompleted: refreshSnapshot()

    Process {
        id: snapshotProcess
        property var controller: root

        command: ["sh", themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-dns-backend.sh", "snapshot"]
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
        onExited: function (exitCode, exitStatus) {
            snapshotProcess.controller.snapshotExitCode = exitCode
            snapshotProcess.controller.snapshotExited = true
            snapshotProcess.controller.maybeFinalizeSnapshot()
        }
    }

    Process {
        id: actionProcess
        property var controller: root

        command: ["sh", themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-dns-backend.sh", root.activeActionId, root.activeActionArg]
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
        onExited: function (exitCode, exitStatus) {
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
        title: "BSDRunner DNS Cache"
        minimumSize: Qt.size(960, 620)
        maximumSize: Qt.size(960, 620)
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
                    height: 108
                    spacing: 14

                    Rectangle {
                        width: 310
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.toneColor(root.headlineTone())

                        Row {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 14

                            Rectangle {
                                width: 52
                                height: 52
                                radius: 26
                                y: 7
                                color: Qt.alpha(root.toneColor(root.headlineTone()), 0.18)
                                border.width: 2
                                border.color: root.toneColor(root.headlineTone())

                                Text {
                                    anchors.centerIn: parent
                                    text: root.badgeText()
                                    color: root.toneColor(root.headlineTone())
                                    font.pixelSize: root.badgeText() === "DNS" ? 16 : 24
                                    font.bold: true
                                }
                            }

                            Column {
                                width: parent.width - 72
                                spacing: 4

                                Text {
                                    width: parent.width
                                    text: root.headline()
                                    color: root.palette.primaryText
                                    font.pixelSize: 28
                                    minimumPixelSize: 20
                                    fontSizeMode: Text.HorizontalFit
                                    font.bold: true
                                }

                                Text {
                                    width: parent.width
                                    text: "Local DNS Cache"
                                    color: root.palette.secondaryText
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Text {
                                    width: parent.width
                                    text: "Unbound local resolver"
                                    color: root.palette.mutedText
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 304
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.panelBorder

                        Row {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 12

                            Repeater {
                                model: [
                                    {
                                        "label": "Service",
                                        "value": root.serviceRunning ? "Running" : "Stopped",
                                        "tone": root.serviceRunning ? "success" : "warning"
                                    },
                                    {
                                        "label": "Boot",
                                        "value": root.bootEnabled ? "Enabled" : "Disabled",
                                        "tone": root.bootEnabled ? "success" : "warning"
                                    },
                                    {
                                        "label": "Setup",
                                        "value": root.hasSetup ? "Ready" : "Fallback",
                                        "tone": root.hasSetup ? "success" : "info"
                                    }
                                ]

                                delegate: Rectangle {
                                    required property var modelData

                                    width: 84
                                    height: 78
                                    radius: 8
                                    color: root.palette.panelBackground
                                    border.width: 1
                                    border.color: root.toneColor(modelData.tone)

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 9
                                        spacing: 5

                                        Text {
                                            width: parent.width
                                            text: modelData.label
                                            color: root.palette.mutedText
                                            font.pixelSize: 10
                                            font.bold: true
                                        }

                                        Text {
                                            width: parent.width
                                            text: modelData.value
                                            color: root.toneColor(modelData.tone)
                                            font.pixelSize: 14
                                            minimumPixelSize: 10
                                            fontSizeMode: Text.HorizontalFit
                                            font.bold: true
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width - 310 - 304 - 28
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
                                text: "Status"
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
                                maximumLineCount: root.statusDetailText().length > 0 ? 2 : 3
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                visible: root.statusDetailText().length > 0
                                text: root.statusDetailText()
                                color: root.palette.mutedText
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
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
                            {
                                "id": "enable",
                                "label": "Enable",
                                "description": "Enable local_unbound and route this laptop through the local cache."
                            },
                            {
                                "id": "restart",
                                "label": "Restart",
                                "description": "Restart local_unbound."
                            },
                            {
                                "id": "flush",
                                "label": "Flush",
                                "description": "Clear cached DNS answers."
                            },
                            {
                                "id": root.encryptedForwarding ? "disable_dot" : "enable_dot",
                                "label": root.encryptedForwarding ? "Plain DNS" : "Encrypt DNS",
                                "description": root.encryptedForwarding
                                    ? "Switch public DNS forwarding back to ordinary unencrypted DNS. Local router domains stay unchanged."
                                    : "Switch public DNS forwarding to DNS-over-TLS using Cloudflare and Google with certificate verification. Local router domains stay unchanged."
                            },
                            {
                                "id": "disable",
                                "label": "Disable",
                                "description": "Stop local_unbound and disable it at boot."
                            }
                        ]

                        delegate: Rectangle {
                            id: actionButton

                            required property var modelData
                            readonly property bool dangerous: modelData.id === "disable"
                            readonly property bool actionEnabled: root.actionAvailable(modelData.id) && !root.runningAction
                            readonly property bool hovered: actionMouse.containsMouse && actionEnabled

                            width: (parent.width - 40) / 5
                            height: parent.height
                            radius: 8
                            color: hovered ? root.palette.cardHover : root.palette.cardBackground
                            border.width: 1
                            border.color: dangerous && actionEnabled ? root.palette.warning : root.palette.panelBorder
                            opacity: actionEnabled ? 1.0 : 0.42

                            Text {
                                anchors.centerIn: parent
                                text: actionButton.modelData.label
                                color: actionButton.actionEnabled
                                    ? (actionButton.dangerous ? root.palette.warning : root.palette.primaryText)
                                    : root.palette.mutedText
                                font.pixelSize: 13
                                font.bold: true
                            }

                            MouseArea {
                                id: actionMouse

                                anchors.fill: parent
                                enabled: actionButton.actionEnabled
                                hoverEnabled: actionButton.actionEnabled
                                cursorShape: actionButton.actionEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.requestAction(actionButton.modelData.id, actionButton.modelData.label, actionButton.modelData.description)
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: parent.height - 108 - 46 - 28
                    spacing: 14

                    Rectangle {
                        width: (parent.width - 14) / 2
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.panelBorder

                        Column {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 12

                            Text {
                                width: parent.width
                                text: "Resolver"
                                color: root.palette.accent
                                font.pixelSize: 16
                                font.bold: true
                            }

                            Rectangle {
                                width: parent.width
                                height: 96
                                radius: 8
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.localResolverActive ? root.palette.success : root.palette.warning

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 5

                                    Text {
                                        width: parent.width
                                        text: root.localResolverActive ? "Localhost" : "External"
                                        color: root.localResolverActive ? root.palette.success : root.palette.warning
                                        font.pixelSize: 18
                                        font.bold: true
                                    }

                                    Text {
                                        width: parent.width
                                        text: root.localResolverActive ? "127.0.0.1 / ::1" : "From /etc/resolv.conf"
                                        color: root.palette.secondaryText
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        visible: root.searchDomain.length > 0
                                        text: root.searchDomain
                                        color: root.palette.mutedText
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: (parent.height - 96 - 16 - 24 - 10) / 2
                                radius: 8
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.frameBorder

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8

                                    Text {
                                        width: parent.width
                                        text: "System Nameservers"
                                        color: root.palette.mutedText
                                        font.pixelSize: 11
                                        font.bold: true
                                    }

                                    Text {
                                        width: parent.width
                                        text: root.nameserverText()
                                        color: root.palette.primaryText
                                        font.pixelSize: 15
                                        font.family: "monospace"
                                        wrapMode: Text.WrapAnywhere
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: (parent.height - 96 - 16 - 24 - 10) / 2
                                radius: 8
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.encryptedForwarding ? root.palette.success : root.palette.frameBorder

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8

                                    Row {
                                        width: parent.width
                                        height: 16
                                        spacing: 8

                                        Text {
                                            width: parent.width - 54
                                            height: parent.height
                                            text: "Forwarding Resolvers"
                                            color: root.palette.mutedText
                                            font.pixelSize: 11
                                            font.bold: true
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        Rectangle {
                                            width: 46
                                            height: 16
                                            radius: 8
                                            color: Qt.alpha(root.encryptedForwarding ? root.palette.success : root.palette.warning, 0.16)
                                            border.width: 1
                                            border.color: root.encryptedForwarding ? root.palette.success : root.palette.warning

                                            Text {
                                                anchors.centerIn: parent
                                                text: root.encryptedForwarding ? "TLS" : "Plain"
                                                color: root.encryptedForwarding ? root.palette.success : root.palette.warning
                                                font.pixelSize: 9
                                                font.bold: true
                                            }
                                        }
                                    }

                                    Flickable {
                                        id: forwarderFlickable

                                        width: parent.width
                                        height: parent.height - 24
                                        contentWidth: width
                                        contentHeight: forwarderList.height
                                        clip: true
                                        boundsBehavior: Flickable.StopAtBounds

                                        Column {
                                            id: forwarderList

                                            width: forwarderFlickable.width
                                            spacing: 6

                                            Text {
                                                width: parent.width
                                                visible: !root.forwarders || root.forwarders.length === 0
                                                text: "No forward zones found"
                                                color: root.palette.primaryText
                                                font.pixelSize: 13
                                                font.family: "monospace"
                                                wrapMode: Text.WrapAnywhere
                                            }

                                            Repeater {
                                                model: root.forwarders || []

                                                delegate: Column {
                                                    id: forwarderBlock

                                                    required property var modelData
                                                    readonly property var targets: root.forwarderTargets(forwarderBlock.modelData)

                                                    width: parent.width
                                                    height: targets.length * 18 + Math.max(0, targets.length - 1) * 2
                                                    spacing: 2

                                                    Repeater {
                                                        model: forwarderBlock.targets

                                                        delegate: Row {
                                                            id: targetRow

                                                            required property int index
                                                            required property var modelData

                                                            width: forwarderBlock.width
                                                            height: 18
                                                            spacing: 8

                                                            Text {
                                                                width: 104
                                                                height: parent.height
                                                                text: targetRow.index === 0 ? root.forwarderZoneLabel(forwarderBlock.modelData.zone) : ""
                                                                color: root.palette.primaryText
                                                                font.pixelSize: 12
                                                                font.family: "monospace"
                                                                verticalAlignment: Text.AlignVCenter
                                                                elide: Text.ElideRight
                                                            }

                                                            Text {
                                                                width: 18
                                                                height: parent.height
                                                                text: "->"
                                                                color: root.palette.mutedText
                                                                font.pixelSize: 12
                                                                font.family: "monospace"
                                                                horizontalAlignment: Text.AlignHCenter
                                                                verticalAlignment: Text.AlignVCenter
                                                            }

                                                            Text {
                                                                width: parent.width - 138
                                                                height: parent.height
                                                                text: targetRow.modelData
                                                                color: root.palette.primaryText
                                                                font.pixelSize: 12
                                                                font.family: "monospace"
                                                                verticalAlignment: Text.AlignVCenter
                                                                elide: Text.ElideRight
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: (parent.width - 14) / 2
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.panelBorder

                        Column {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 12

                            Text {
                                width: parent.width
                                text: "Lookup Test"
                                color: root.palette.accent
                                font.pixelSize: 16
                                font.bold: true
                            }

                            Row {
                                width: parent.width
                                height: 42
                                spacing: 10

                                Rectangle {
                                    width: parent.width - 130
                                    height: parent.height
                                    radius: 8
                                    color: root.palette.panelBackground
                                    border.width: 1
                                    border.color: lookupInput.activeFocus ? root.palette.accent : root.palette.frameBorder

                                    TextInput {
                                        id: lookupInput

                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        verticalAlignment: TextInput.AlignVCenter
                                        text: root.lookupName
                                        color: root.palette.primaryText
                                        selectionColor: Qt.alpha(root.palette.accent, 0.35)
                                        selectedTextColor: root.palette.primaryText
                                        font.pixelSize: 15
                                        clip: true
                                        onTextChanged: root.lookupName = text
                                        onAccepted: root.runLookup()
                                    }
                                }

                                Rectangle {
                                    width: 120
                                    height: parent.height
                                    radius: 8
                                    color: testMouse.containsMouse ? root.palette.cardHover : root.palette.panelBackground
                                    border.width: 1
                                    border.color: root.palette.accent
                                    opacity: root.runningAction ? 0.5 : 1.0

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Test"
                                        color: root.palette.primaryText
                                        font.pixelSize: 13
                                        font.bold: true
                                    }

                                    MouseArea {
                                        id: testMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.runLookup()
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: parent.height - 16 - 42 - 24
                                radius: 8
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.frameBorder

                                Flickable {
                                    id: detailFlickable

                                    anchors.fill: parent
                                    anchors.margins: 12
                                    contentWidth: width
                                    contentHeight: detailText.height
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds

                                    Text {
                                        id: detailText

                                        width: detailFlickable.width
                                        text: root.actionDetails.length > 0 ? root.actionDetails : root.lastResultMessage
                                        color: root.palette.secondaryText
                                        font.pixelSize: 13
                                        font.family: root.actionDetails.length > 0 ? "monospace" : ""
                                        wrapMode: Text.WrapAnywhere
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
                color: Qt.rgba(0, 0, 0, 0.58)

                Rectangle {
                    width: 420
                    height: 178
                    anchors.centerIn: parent
                    radius: 8
                    color: root.palette.cardBackground
                    border.width: 1
                    border.color: root.pendingActionId === "disable" ? root.palette.warning : root.palette.accent

                    Column {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 14

                        Text {
                            width: parent.width
                            text: root.pendingActionLabel
                            color: root.palette.primaryText
                            font.pixelSize: 20
                            font.bold: true
                        }

                        Text {
                            width: parent.width
                            text: root.pendingActionDescription
                            color: root.palette.secondaryText
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                        }

                        Row {
                            width: parent.width
                            height: 38
                            spacing: 10

                            Rectangle {
                                width: (parent.width - 10) / 2
                                height: parent.height
                                radius: 8
                                color: confirmMouse.containsMouse ? root.palette.cardHover : root.palette.panelBackground
                                border.width: 1
                                border.color: root.pendingActionId === "disable" ? root.palette.warning : root.palette.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: "Confirm"
                                    color: root.palette.primaryText
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                MouseArea {
                                    id: confirmMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.confirmPendingAction()
                                }
                            }

                            Rectangle {
                                width: (parent.width - 10) / 2
                                height: parent.height
                                radius: 8
                                color: cancelMouse.containsMouse ? root.palette.cardHover : root.palette.panelBackground
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
                                    id: cancelMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
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
