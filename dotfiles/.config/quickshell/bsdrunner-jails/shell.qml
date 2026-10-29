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
    property bool beginnerMapVisible: true
    property string statusTone: "info"
    property string statusMessage: "Loading jail status..."
    property string actionDetails: ""
    property string activeActionId: ""
    property string activeActionName: ""
    property string activeActionBackend: ""
    property string activeActionLabel: ""
    property string pendingActionId: ""
    property string pendingActionLabel: ""
    property string pendingActionDescription: ""
    property string selectedJailName: ""
    property string selectedJailBackend: ""
    property string selectedBeginnerTopic: "storage"
    property var runningJails: []
    property var configuredJails: []
    property var bastilleJails: []
    property var tools: ({})
    property var services: ({})
    property string lastResultTone: "info"
    property string lastResultMessage: "No jail action has run yet."
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

    readonly property var jails: mergedJails()
    readonly property var selectedJail: findJail(selectedJailName, selectedJailBackend)
    readonly property var beginnerTopics: [
        {
            "id": "storage",
            "title": "1. Storage",
            "body": "A jail needs a filesystem root. ZFS datasets are the cleanest place to keep those roots.",
            "detail": "Start by deciding where jail roots live. On a ZFS machine, a dataset like zroot/jails keeps jail files separate and makes snapshots, quotas, and cleanup easier to reason about."
        },
        {
            "id": "userland",
            "title": "2. Userland",
            "body": "FreeBSD does not create a full system tree by itself. You fetch or extract a release first.",
            "detail": "The jail shares the host kernel, but it still needs its own /bin, /etc, /usr, and packages. Bastille can bootstrap this; native jails usually start from a fetched base.txz or an existing template."
        },
        {
            "id": "config",
            "title": "3. Config",
            "body": "jail.conf gives the jail a name, path, hostname, network address, and startup behavior.",
            "detail": "The config is the contract between the host and the jail. It points at the root path, names the jail, chooses networking, controls devfs, and decides whether service jail start should include it."
        },
        {
            "id": "lifecycle",
            "title": "4. Lifecycle",
            "body": "Once configured, start, stop, restart, and console are the everyday operations.",
            "detail": "After setup, jails feel like small service machines. Start boots the jail, console gets you inside, restart applies many config changes, and stop shuts the contained userland down."
        }
    ]
    readonly property var selectedBeginner: findBeginnerTopic(selectedBeginnerTopic)

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

    function mergedJails() {
        var merged = []
        var seen = {}
        addJails(merged, seen, runningJails || [])
        addJails(merged, seen, bastilleJails || [])
        addJails(merged, seen, configuredJails || [])
        return merged
    }

    function addJails(target, seen, source) {
        for (var i = 0; i < source.length; i += 1) {
            var jail = source[i]
            var key = (jail.backend || "native") + ":" + (jail.name || jail.hostname || jail.jid)
            if (!key || seen[key])
                continue
            seen[key] = true
            target.push(jail)
        }
    }

    function findJail(name, backend) {
        var all = jails
        for (var i = 0; i < all.length; i += 1) {
            if (all[i].name === name && all[i].backend === backend)
                return all[i]
        }
        return null
    }

    function findBeginnerTopic(topicId) {
        for (var i = 0; i < beginnerTopics.length; i += 1) {
            if (beginnerTopics[i].id === topicId)
                return beginnerTopics[i]
        }
        return beginnerTopics.length > 0 ? beginnerTopics[0] : null
    }

    function selectJail(jail) {
        selectedJailName = jail ? jail.name || "" : ""
        selectedJailBackend = jail ? jail.backend || "native" : ""
        clearPendingAction()
    }

    function headline() {
        if (!tools.jls && !tools.bastille)
            return "No Jail Tools"
        if (jails.length === 0)
            return "No Jails Yet"
        if (runningCount() > 0)
            return runningCount() + " Running"
        return "Jails Ready"
    }

    function headlineTone() {
        if (!tools.jls && !tools.bastille)
            return "error"
        if (runningCount() > 0)
            return "success"
        if (jails.length > 0)
            return "warning"
        return "info"
    }

    function runningCount() {
        var count = 0
        for (var i = 0; i < jails.length; i += 1) {
            if ((jails[i].state || "").toLowerCase() === "running")
                count += 1
        }
        return count
    }

    function backendLabel(jail) {
        if (!jail)
            return "No backend"
        return jail.backend === "bastille" ? "Bastille" : "Native jail"
    }

    function stateTone(jail) {
        if (!jail)
            return "info"
        var state = (jail.state || "").toLowerCase()
        if (state === "running")
            return "success"
        if (state === "configured" || state === "stopped")
            return "warning"
        return "info"
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

    function valueOrUnknown(value) {
        if (!value || value === "-" || value === "unknown")
            return "Unknown"
        return value
    }

    function canStart(jail) {
        return jail && (jail.state || "").toLowerCase() !== "running"
    }

    function canStop(jail) {
        return jail && (jail.state || "").toLowerCase() === "running"
    }

    function canConsole(jail) {
        return canStop(jail)
    }

    function actionAvailable(actionId) {
        if (!selectedJail || runningAction)
            return false
        if (actionId === "start")
            return canStart(selectedJail)
        if (actionId === "stop")
            return canStop(selectedJail)
        if (actionId === "restart")
            return selectedJail.state === "running"
        if (actionId === "console")
            return canConsole(selectedJail)
        return true
    }

    function requestAction(actionId, label, description) {
        if (!actionAvailable(actionId))
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
        if (!pendingActionId || !selectedJail)
            return
        activeActionId = pendingActionId
        activeActionName = selectedJail.name
        activeActionBackend = selectedJail.backend || "native"
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
            statusMessage = "The Jails backend returned invalid JSON."
            actionDetails = stderrText || text || ""
            return
        }

        if (exitCode !== 0 || !payload.ok) {
            statusTone = "error"
            statusMessage = payload.message || stderrText || "Unable to load jail status."
            return
        }

        tools = payload.tools || {}
        services = payload.services || {}
        runningJails = payload.running || []
        configuredJails = payload.configured || []
        bastilleJails = payload.bastille || []
        lastResultTone = payload.last_result ? payload.last_result.tone || "info" : "info"
        lastResultMessage = payload.last_result ? payload.last_result.message || payload.message : payload.message
        lastResultTimestamp = payload.last_result ? payload.last_result.timestamp || "" : ""
        statusTone = lastResultTone
        statusMessage = payload.message || "Loaded jail status."

        if (jails.length > 0 && !findJail(selectedJailName, selectedJailBackend))
            selectJail(jails[0])
        else if (jails.length === 0)
            selectJail(null)
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
            statusTone = activeActionId === "stop" ? "warning" : "success"
            statusMessage = payload.message || "Jail action completed."
            actionDetails = payload.details || ""
        } else if (payload) {
            statusTone = "error"
            statusMessage = payload.message || "Jail action failed."
            actionDetails = payload.details || stderrText || ""
        } else {
            statusTone = "error"
            statusMessage = "The Jails backend returned invalid JSON."
            actionDetails = stderrText || text || ""
        }

        activeActionId = ""
        activeActionName = ""
        activeActionBackend = ""
        activeActionLabel = ""
        refreshSnapshot()
    }

    Component.onCompleted: refreshSnapshot()

    Process {
        id: snapshotProcess
        property var controller: root

        command: ["sh", themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-jails-backend.sh", "snapshot"]
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
        onExited: function (exitCode) {
            snapshotProcess.controller.snapshotExitCode = exitCode
            snapshotProcess.controller.snapshotExited = true
            snapshotProcess.controller.maybeFinalizeSnapshot()
        }
    }

    Process {
        id: actionProcess
        property var controller: root

        command: ["sh", themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-jails-backend.sh", root.activeActionId, root.activeActionName, root.activeActionBackend]
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
        onExited: function (exitCode) {
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
        title: "BSDRunner Jails"
        minimumSize: Qt.size(1080, 660)
        maximumSize: Qt.size(1080, 660)
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
                    height: 104
                    spacing: 14

                    Rectangle {
                        width: 320
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
                                width: 54
                                height: 54
                                radius: 27
                                y: 7
                                color: Qt.alpha(root.toneColor(root.headlineTone()), 0.18)
                                border.width: 2
                                border.color: root.toneColor(root.headlineTone())

                                Text {
                                    anchors.centerIn: parent
                                    text: "JLS"
                                    color: root.toneColor(root.headlineTone())
                                    font.pixelSize: 14
                                    font.bold: true
                                }
                            }

                            Column {
                                width: parent.width - 74
                                spacing: 4

                                Text {
                                    width: parent.width
                                    text: root.headline()
                                    color: root.palette.primaryText
                                    font.pixelSize: 27
                                    minimumPixelSize: 18
                                    fontSizeMode: Text.HorizontalFit
                                    font.bold: true
                                }

                                Text {
                                    width: parent.width
                                    text: root.jails.length + " known, " + root.runningCount() + " running"
                                    color: root.palette.secondaryText
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Text {
                                    width: parent.width
                                    text: root.tools.bastille ? "Bastille detected" : "Native jail mode"
                                    color: root.palette.mutedText
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width - 334
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.toneColor(root.statusTone)

                        Row {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12

                            Rectangle {
                                width: 8
                                height: parent.height
                                radius: 4
                                color: root.toneColor(root.statusTone)
                            }

                            Column {
                                width: parent.width - 280
                                spacing: 6

                                Text {
                                    width: parent.width
                                    text: root.statusMessage
                                    color: root.palette.primaryText
                                    font.pixelSize: 18
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: root.statusDetailText().length > 0 ? root.statusDetailText() : "Jails share the FreeBSD kernel. Each jail gets its own userland, network identity, and filesystem root."
                                    color: root.palette.secondaryText
                                    font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                            }

                            Rectangle {
                                width: 112
                                height: 38
                                radius: 7
                                color: mapToggleMouse.containsMouse ? root.palette.cardHover : root.palette.panelBackground
                                border.width: 1
                                border.color: root.beginnerMapVisible ? root.palette.accent : root.palette.panelBorder
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: root.beginnerMapVisible ? "Hide Map" : "Show Map"
                                    color: root.beginnerMapVisible ? root.palette.accent : root.palette.primaryText
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                MouseArea {
                                    id: mapToggleMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.beginnerMapVisible = !root.beginnerMapVisible
                                }
                            }

                            Rectangle {
                                width: 120
                                height: 38
                                radius: 7
                                color: refreshMouse.containsMouse ? root.palette.cardHover : root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.panelBorder
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: root.loading ? "Loading" : "Refresh"
                                    color: root.palette.primaryText
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                MouseArea {
                                    id: refreshMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !root.loading && !root.runningAction
                                    onClicked: root.refreshSnapshot()
                                }
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: parent.height - 118
                    spacing: 14

                    Rectangle {
                        width: 316
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.frameBorder

                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            Text {
                                width: parent.width
                                text: "Jail Inventory"
                                color: root.palette.accent
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Rectangle {
                                width: parent.width
                                height: 38
                                radius: 7
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.panelBorder

                                Text {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    text: root.jails.length === 0 ? "No configured jails found" : "Select a jail to inspect it"
                                    color: root.palette.secondaryText
                                    font.pixelSize: 12
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                            }

                            Flickable {
                                width: parent.width
                                height: parent.height - 90
                                contentHeight: jailListColumn.height
                                clip: true

                                Column {
                                    id: jailListColumn
                                    width: parent.width
                                    spacing: 8

                                    Repeater {
                                        model: root.jails

                                        Rectangle {
                                            id: jailRow
                                            required property var modelData

                                            width: jailListColumn.width
                                            height: 78
                                            radius: 8
                                            color: root.selectedJailName === jailRow.modelData.name && root.selectedJailBackend === jailRow.modelData.backend ? root.palette.cardHover : root.palette.panelBackground
                                            border.width: 1
                                            border.color: root.selectedJailName === jailRow.modelData.name && root.selectedJailBackend === jailRow.modelData.backend ? root.toneColor(root.stateTone(jailRow.modelData)) : root.palette.frameBorder

                                            Row {
                                                anchors.fill: parent
                                                anchors.margins: 10
                                                spacing: 10

                                                Rectangle {
                                                    width: 12
                                                    height: 12
                                                    radius: 6
                                                    color: root.toneColor(root.stateTone(jailRow.modelData))
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                Column {
                                                    width: parent.width - 22
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    spacing: 3

                                                    Text {
                                                        width: parent.width
                                                        text: jailRow.modelData.name || "Unnamed jail"
                                                        color: root.palette.primaryText
                                                        font.pixelSize: 15
                                                        font.bold: true
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        width: parent.width
                                                        text: root.backendLabel(jailRow.modelData) + " / " + root.valueOrUnknown(jailRow.modelData.state)
                                                        color: root.palette.secondaryText
                                                        font.pixelSize: 12
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        width: parent.width
                                                        text: root.valueOrUnknown(jailRow.modelData.ipv4)
                                                        color: root.palette.mutedText
                                                        font.pixelSize: 11
                                                        elide: Text.ElideRight
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: root.selectJail(jailRow.modelData)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: root.beginnerMapVisible ? 382 : parent.width - 330
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.frameBorder

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 14
                            contentWidth: width
                            contentHeight: centerContent.height
                            clip: true

                            Column {
                                id: centerContent

                                width: parent.width
                                spacing: 12

                            Text {
                                width: parent.width
                                text: root.selectedJail ? root.selectedJail.name : "Select a jail"
                                color: root.palette.primaryText
                                font.pixelSize: 24
                                minimumPixelSize: 16
                                fontSizeMode: Text.HorizontalFit
                                font.bold: true
                            }

                            Text {
                                width: parent.width
                                text: root.selectedJail ? root.backendLabel(root.selectedJail) + " / " + root.valueOrUnknown(root.selectedJail.state) : "A jail is a lightweight FreeBSD system boundary."
                                color: root.selectedJail ? root.toneColor(root.stateTone(root.selectedJail)) : root.palette.secondaryText
                                font.pixelSize: 13
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Grid {
                                width: parent.width
                                columns: 2
                                rowSpacing: 8
                                columnSpacing: 8

                                Repeater {
                                    model: [
                                        {"label": "JID", "value": root.selectedJail ? root.valueOrUnknown(root.selectedJail.jid) : "None"},
                                        {"label": "IP address", "value": root.selectedJail ? root.valueOrUnknown(root.selectedJail.ipv4) : "None"},
                                        {"label": "Hostname", "value": root.selectedJail ? root.valueOrUnknown(root.selectedJail.hostname) : "None"},
                                        {"label": "Autostart", "value": root.selectedJail ? root.valueOrUnknown(root.selectedJail.autostart) : "None"},
                                        {"label": "Release", "value": root.selectedJail ? root.valueOrUnknown(root.selectedJail.release) : "None"},
                                        {"label": "Root path", "value": root.selectedJail ? root.valueOrUnknown(root.selectedJail.path) : "None"}
                                    ]

                                    Rectangle {
                                        id: detailCell
                                        required property var modelData

                                        width: (parent.width - 8) / 2
                                        height: 58
                                        radius: 7
                                        color: root.palette.panelBackground
                                        border.width: 1
                                        border.color: root.palette.frameBorder

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 3

                                            Text {
                                                width: parent.width
                                                text: detailCell.modelData.label
                                                color: root.palette.mutedText
                                                font.pixelSize: 10
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                width: parent.width
                                                text: detailCell.modelData.value
                                                color: root.palette.primaryText
                                                font.pixelSize: 13
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: root.pendingActionId ? 108 : 0
                                visible: root.pendingActionId.length > 0
                                radius: 8
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.toneColor("warning")

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8

                                    Text {
                                        width: parent.width
                                        text: root.pendingActionLabel
                                        color: root.palette.primaryText
                                        font.pixelSize: 14
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        text: root.pendingActionDescription
                                        color: root.palette.secondaryText
                                        font.pixelSize: 12
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }

                                    Row {
                                        width: parent.width
                                        height: 28
                                        spacing: 8

                                        Rectangle {
                                            width: 92
                                            height: parent.height
                                            radius: 6
                                            color: confirmMouse.containsMouse ? root.palette.cardHover : Qt.alpha(root.palette.warning, 0.18)
                                            border.width: 1
                                            border.color: root.palette.warning

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Confirm"
                                                color: root.palette.primaryText
                                                font.pixelSize: 12
                                                font.bold: true
                                            }

                                            MouseArea {
                                                id: confirmMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: root.confirmPendingAction()
                                            }
                                        }

                                        Rectangle {
                                            width: 80
                                            height: parent.height
                                            radius: 6
                                            color: cancelMouse.containsMouse ? root.palette.cardHover : root.palette.cardBackground
                                            border.width: 1
                                            border.color: root.palette.panelBorder

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Cancel"
                                                color: root.palette.secondaryText
                                                font.pixelSize: 12
                                                font.bold: true
                                            }

                                            MouseArea {
                                                id: cancelMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: root.clearPendingAction()
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                text: "Actions"
                                color: root.palette.accent
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Grid {
                                width: parent.width
                                columns: 2
                                rowSpacing: 8
                                columnSpacing: 8

                                Repeater {
                                    model: [
                                        {"id": "start", "label": "Start", "detail": "Boot this jail userland"},
                                        {"id": "stop", "label": "Stop", "detail": "Shut the jail down"},
                                        {"id": "restart", "label": "Restart", "detail": "Stop, then start again"},
                                        {"id": "console", "label": "Console", "detail": "Open a root shell"}
                                    ]

                                    Rectangle {
                                        id: actionCell
                                        required property var modelData

                                        width: (parent.width - 8) / 2
                                        height: 58
                                        radius: 7
                                        color: actionMouse.containsMouse && root.actionAvailable(actionCell.modelData.id) ? root.palette.cardHover : root.palette.panelBackground
                                        opacity: root.actionAvailable(actionCell.modelData.id) ? 1.0 : 0.45
                                        border.width: 1
                                        border.color: root.palette.panelBorder

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 3

                                            Text {
                                                width: parent.width
                                                text: actionCell.modelData.label
                                                color: root.palette.primaryText
                                                font.pixelSize: 13
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                width: parent.width
                                                text: actionCell.modelData.detail
                                                color: root.palette.secondaryText
                                                font.pixelSize: 11
                                                elide: Text.ElideRight
                                            }
                                        }

                                        MouseArea {
                                            id: actionMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            enabled: root.actionAvailable(actionCell.modelData.id)
                                            onClicked: root.requestAction(actionCell.modelData.id, actionCell.modelData.label, actionCell.modelData.label + " " + root.selectedJail.name + "?")
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 76
                                radius: 8
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.frameBorder

                                Text {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    text: root.selectedJail ? "Tip: start with a service jail for things like Postgres, Redis, nginx, or a development daemon. Desktop app jails need extra display, audio, and file permissions." : "Pick a jail from the inventory to see safe lifecycle actions."
                                    color: root.palette.secondaryText
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                }
                            }
                            }
                        }
                    }

                    Rectangle {
                        visible: root.beginnerMapVisible
                        width: root.beginnerMapVisible ? parent.width - 726 : 0
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.frameBorder

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 14
                            contentWidth: width
                            contentHeight: beginnerContent.height
                            clip: true

                            Column {
                                id: beginnerContent

                                width: parent.width
                                spacing: 12

                            Text {
                                width: parent.width
                                text: "Beginner Map"
                                color: root.palette.accent
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Repeater {
                                model: root.beginnerTopics

                                Rectangle {
                                    id: mapCard
                                    required property var modelData
                                    readonly property bool selected: root.selectedBeginnerTopic === modelData.id

                                    width: parent.width
                                    height: 78
                                    radius: 8
                                    color: mapMouse.containsMouse ? root.palette.cardHover : (selected ? Qt.alpha(root.palette.accent, 0.14) : root.palette.panelBackground)
                                    border.width: 1
                                    border.color: selected ? root.palette.accent : root.palette.frameBorder

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 4

                                        Text {
                                            width: parent.width
                                            text: mapCard.modelData.title
                                            color: root.palette.primaryText
                                            font.pixelSize: 13
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: parent.width
                                            text: mapCard.modelData.body
                                            color: root.palette.secondaryText
                                            font.pixelSize: 11
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 3
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        id: mapMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selectedBeginnerTopic = mapCard.modelData.id
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 124
                                radius: 8
                                color: Qt.alpha(root.palette.accent, 0.10)
                                border.width: 1
                                border.color: root.palette.accent

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 6

                                    Text {
                                        width: parent.width
                                        text: root.selectedBeginner ? root.selectedBeginner.title : "Beginner Map"
                                        color: root.palette.primaryText
                                        font.pixelSize: 13
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        text: root.selectedBeginner ? root.selectedBeginner.detail : ""
                                        color: root.palette.secondaryText
                                        font.pixelSize: 11
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 5
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 86
                                radius: 8
                                color: root.tools.bastille ? Qt.alpha(root.palette.success, 0.12) : root.palette.panelBackground
                                border.width: 1
                                border.color: root.tools.bastille ? root.palette.success : root.palette.frameBorder

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 4

                                    Text {
                                        width: parent.width
                                        text: "Bastille"
                                        color: root.tools.bastille ? root.palette.success : root.palette.primaryText
                                        font.pixelSize: 13
                                        font.bold: true
                                    }

                                    Text {
                                        width: parent.width
                                        text: root.tools.bastille ? "Installed. This UI can list Bastille jails and use Bastille lifecycle commands." : "Not installed. Native jail status still works; Bastille can remain an optional automation layer."
                                        color: root.palette.secondaryText
                                        font.pixelSize: 11
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 86
                                radius: 8
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.frameBorder

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 4

                                    Text {
                                        width: parent.width
                                        text: "Create Jail"
                                        color: root.palette.primaryText
                                        font.pixelSize: 13
                                        font.bold: true
                                    }

                                    Text {
                                        width: parent.width
                                        text: "V1 avoids destructive setup. Use ZFS to create storage, then add a simple jail.conf.d file; creation wizard comes after status feels trustworthy."
                                        color: root.palette.secondaryText
                                        font.pixelSize: 11
                                        wrapMode: Text.WordWrap
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
