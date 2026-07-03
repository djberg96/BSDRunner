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
    property string statusMessage: "Loading network status..."
    property string actionDetails: ""
    property string activeActionId: ""
    property string activeActionArg: ""
    property string activeActionSecret: ""
    property string activeActionBssid: ""
    property string activeActionLabel: ""
    property string lookupName: "freebsd.org"
    property string pingName: "10.50.0.1"
    property string traceName: "freebsd.org"
    property string httpUrl: "https://www.youtube.com/"
    property string selectedTool: "ping"
    property string lastToolId: ""
    property bool helpDialogVisible: false
    property bool joinDialogVisible: false
    property bool joinSsidEditable: false
    property string joinSsid: ""
    property string joinBssid: ""
    property string joinPassword: ""
    property var interfaceInfo: ({})
    property var routeInfo: ({})
    property var tools: ({})
    property var scanRows: []
    property string scanFilter: "all"
    property var logLines: []
    property var dnsPolicy: ({})
    property var printers: ({})
    property var lastResult: ({})
    property string rightPanelTab: "events"
    property bool featureTooltipVisible: false
    property string featureTooltipText: ""
    property real featureTooltipX: 0
    property real featureTooltipY: 0
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

    function ifaceValue(key) {
        return interfaceInfo && interfaceInfo[key] ? interfaceInfo[key] : ""
    }

    function closeHelpDialog() {
        helpDialogVisible = false
    }

    function scanRowsForFilter(filterId) {
        var rows = scanRows || []
        if (filterId === "all")
            return rows

        var filtered = []
        for (var i = 0; i < rows.length; i++) {
            var row = rows[i] || {}
            if (filterId === "2.4" && row.band === "2.4 GHz")
                filtered.push(row)
            else if (filterId === "5" && row.band === "5 GHz")
                filtered.push(row)
            else if (filterId === "hotspot" && row.hotspot)
                filtered.push(row)
        }
        return filtered
    }

    function filteredScanRows() {
        return scanRowsForFilter(scanFilter)
    }

    function scanFilterCount(filterId) {
        return scanRowsForFilter(filterId).length
    }

    function routeValue(key) {
        return routeInfo && routeInfo[key] ? routeInfo[key] : ""
    }

    function dnsValue(key) {
        return dnsPolicy && dnsPolicy[key] ? dnsPolicy[key] : ""
    }

    function dnsResolversText() {
        var resolvers = dnsPolicy && dnsPolicy.resolvers ? dnsPolicy.resolvers : []
        if (resolvers.length === 0)
            return "No resolvers found"
        return resolvers.join(", ")
    }

    function dnsCheckTarget(check) {
        if (!check)
            return "-"
        if (check.cname && check.cname.length > 0)
            return check.cname
        if (check.address && check.address.length > 0)
            return check.address
        return "-"
    }

    function dnsCheckTone(check) {
        if (!check || !check.ok)
            return "warning"
        if (check.classification && check.classification.indexOf("youtube") === 0)
            return "warning"
        return "success"
    }

    function printerList(key) {
        return printers && printers[key] ? printers[key] : []
    }

    function printerSummary() {
        return printerList("discovered").length + " discovered / " + printerList("configured").length + " configured"
    }

    function printerCapabilityText(printer) {
        var parts = []
        if (printer.color === "T")
            parts.push("Color")
        if (printer.duplex === "T")
            parts.push("Duplex")
        if (printer.scan === "T")
            parts.push("Scan")
        return parts.length > 0 ? parts.join(" / ") : "Capabilities unknown"
    }

    function printerAddressText(printer) {
        if (!printer)
            return "-"
        if (printer.address && printer.port)
            return printer.address + ":" + printer.port
        if (printer.hostname)
            return printer.hostname
        return "-"
    }

    function showFeatureTooltip(row) {
        if (!row || !row.hasCaps)
            return

        featureTooltipText = row.modelData.caps
        var below = row.mapToItem(appFrame, 0, row.height + 6)
        var above = row.mapToItem(appFrame, 0, -82)
        featureTooltipX = Math.max(18, Math.min(below.x + row.width - 356, appFrame.width - 374))
        featureTooltipY = below.y + 74 > appFrame.height ? Math.max(18, above.y) : below.y
        featureTooltipVisible = true
    }

    function hideFeatureTooltip() {
        featureTooltipVisible = false
        featureTooltipText = ""
    }

    function headline() {
        if (ifaceValue("ssid").length > 0)
            return ifaceValue("ssid")
        if (ifaceValue("name").length > 0)
            return ifaceValue("name")
        return "No Network"
    }

    function headlineTone() {
        if (ifaceValue("status") === "associated" && ifaceValue("ipv4").length > 0)
            return "success"
        if (ifaceValue("status") === "associated")
            return "warning"
        if (ifaceValue("name").length > 0)
            return "warning"
        return "error"
    }

    function statusDetailText() {
        if (actionDetails.length > 0)
            return firstNonEmptyLine(actionDetails)
        if (lastResult && lastResult.timestamp && lastResult.timestamp.length > 0)
            return "Updated " + compactTimestamp(lastResult.timestamp)
        return ""
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

    function strengthTone(signal) {
        var value = Number(signal)
        if (value >= -55)
            return "success"
        if (value >= -72)
            return "warning"
        return "error"
    }

    function sameBssid(row) {
        return row && row.bssid && ifaceValue("bssid") === row.bssid
    }

    function profileBssid() {
        return ifaceValue("profile_bssid")
    }

    function rowPinned(row) {
        return row && row.bssid && row.ssid && row.ssid === ifaceValue("ssid") && profileBssid() === row.bssid
    }

    function ssidPinned(row) {
        var pinned = profileBssid()
        return row && row.ssid && row.ssid === ifaceValue("ssid") && pinned.length > 0 && pinned !== "any"
    }

    function pinText(row) {
        if (rowPinned(row))
            return "Free"
        if (ssidPinned(row))
            return "Move"
        return "Pin"
    }

    function runPinAction(row) {
        if (!row || !row.ssid || row.ssid === "(hidden)" || runningAction)
            return
        if (rowPinned(row))
            runAction("unpin", "Unpinning " + row.ssid, row.ssid)
        else
            runAction("pin", "Pinning " + row.ssid, row.ssid, "", row.bssid || "")
    }

    function openJoinDialog(row) {
        if (!row || !row.ssid || row.ssid === "(hidden)" || runningAction)
            return
        joinSsidEditable = false
        joinSsid = row.ssid
        joinBssid = row.bssid || ""
        joinPassword = ""
        joinDialogVisible = true
        hideFeatureTooltip()
    }

    function openManualJoinDialog() {
        if (runningAction)
            return
        joinSsidEditable = true
        joinSsid = ""
        joinBssid = ""
        joinPassword = ""
        joinDialogVisible = true
        hideFeatureTooltip()
    }

    function closeJoinDialog() {
        joinDialogVisible = false
        joinSsidEditable = false
        joinSsid = ""
        joinBssid = ""
        joinPassword = ""
    }

    function refreshSnapshot() {
        if (loading)
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

        loading = false
        var text = snapshotStdoutText || ""
        var payload = null

        try {
            payload = JSON.parse(text)
        } catch (error) {
            payload = null
        }

        if (payload && payload.ok && snapshotExitCode === 0) {
            interfaceInfo = payload.interface || {}
            routeInfo = payload.route || {}
            tools = payload.tools || {}
            scanRows = payload.scan || []
            logLines = payload.logs || []
            dnsPolicy = payload.dns_policy || {}
            printers = payload.printers || {}
            lastResult = payload.last_result || {}
            if (!runningAction) {
                statusTone = lastResult.tone || headlineTone()
                statusMessage = lastResult.message || "Network status refreshed."
                actionDetails = ""
            }
        } else {
            statusTone = "error"
            statusMessage = "Unable to load network status."
            actionDetails = snapshotStderrText || text
        }
    }

    function runAction(actionId, label, actionArg, actionSecret, actionBssid) {
        if (runningAction)
            return
        activeActionId = actionId
        activeActionArg = actionArg || ""
        activeActionSecret = actionSecret || ""
        activeActionBssid = actionBssid || ""
        activeActionLabel = label
        runningAction = true
        statusTone = "info"
        statusMessage = label + "..."
        actionDetails = ""
        actionStdoutText = ""
        actionStderrText = ""
        actionExitCode = 0
        actionExited = false
        actionStdoutFinished = false
        actionStderrFinished = false
        actionProcess.running = true
    }

    function runLookup() {
        var name = lookupName.replace(/^\s+|\s+$/g, "")
        if (name.length === 0 || runningAction)
            return
        lookupName = name
        runAction("drill", "Running DNS lookup", name)
    }

    function runPing() {
        var name = pingName.replace(/^\s+|\s+$/g, "")
        if (name.length === 0 || runningAction)
            return
        pingName = name
        runAction("ping", "Pinging " + name, name)
    }

    function runTrace() {
        var name = traceName.replace(/^\s+|\s+$/g, "")
        if (name.length === 0 || runningAction)
            return
        traceName = name
        runAction("traceroute", "Tracing route to " + name, name)
    }

    function runHttpCheck() {
        var url = httpUrl.replace(/^\s+|\s+$/g, "")
        if (url.length === 0 || runningAction)
            return
        httpUrl = url
        runAction("http", "Checking " + url, url)
    }

    function selectedToolName() {
        if (selectedTool === "drill")
            return "Drill"
        if (selectedTool === "traceroute")
            return "Traceroute"
        if (selectedTool === "http")
            return "HTTP"
        return "Ping"
    }

    function selectedToolButtonText() {
        if (selectedTool === "drill")
            return "Drill"
        if (selectedTool === "traceroute")
            return "Trace"
        if (selectedTool === "http")
            return "Check"
        return "Ping"
    }

    function selectedToolHost() {
        if (selectedTool === "drill")
            return lookupName
        if (selectedTool === "traceroute")
            return traceName
        if (selectedTool === "http")
            return httpUrl
        return pingName
    }

    function setSelectedToolHost(value) {
        if (selectedTool === "drill")
            lookupName = value
        else if (selectedTool === "traceroute")
            traceName = value
        else if (selectedTool === "http")
            httpUrl = value
        else
            pingName = value
    }

    function runSelectedTool() {
        if (selectedTool === "drill")
            runLookup()
        else if (selectedTool === "traceroute")
            runTrace()
        else if (selectedTool === "http")
            runHttpCheck()
        else
            runPing()
    }

    function selectedToolHasOutput() {
        return actionDetails.length > 0 && lastToolId === selectedTool
    }

    function runJoin() {
        var ssid = joinSsid.replace(/^\s+|\s+$/g, "")
        if (ssid.length === 0 || runningAction)
            return
        var bssid = joinBssid
        var password = joinPassword
        joinSsid = ssid
        closeJoinDialog()
        runAction("join", "Joining " + ssid, ssid, password, bssid)
    }

    function maybeFinalizeAction() {
        if (!actionExited || !actionStdoutFinished || !actionStderrFinished)
            return

        runningAction = false
        var text = actionStdoutText || ""
        var payload = null

        try {
            payload = JSON.parse(text)
        } catch (error) {
            payload = null
        }

        if (payload && payload.ok && actionExitCode === 0) {
            statusTone = "success"
            statusMessage = payload.message || "Network action completed."
            actionDetails = payload.details || ""
        } else if (payload) {
            statusTone = "warning"
            statusMessage = payload.message || "Network action finished with warnings."
            actionDetails = payload.details || actionStderrText || ""
        } else {
            statusTone = "error"
            statusMessage = "The network backend returned invalid JSON."
            actionDetails = actionStderrText || text || ""
        }

        var completedActionId = activeActionId
        if (completedActionId === "drill" || completedActionId === "ping" || completedActionId === "traceroute" || completedActionId === "http")
            lastToolId = completedActionId
        activeActionId = ""
        activeActionArg = ""
        activeActionSecret = ""
        activeActionBssid = ""
        activeActionLabel = ""
        if (completedActionId !== "drill" && completedActionId !== "ping" && completedActionId !== "traceroute" && completedActionId !== "http")
            refreshSnapshot()
    }

    Component.onCompleted: refreshSnapshot()

    Process {
        id: snapshotProcess
        property var controller: root

        command: ["sh", themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-network-backend.sh", "snapshot"]
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

        command: ["sh", themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-network-backend.sh", root.activeActionId, root.activeActionArg, root.activeActionSecret, root.activeActionBssid]
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
        title: "BSDRunner Network"
        minimumSize: Qt.size(1040, 660)
        maximumSize: Qt.size(1040, 660)
        color: "transparent"

        Rectangle {
            id: appFrame

            anchors.fill: parent
            color: root.palette.panelBackground

            Column {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                Row {
                    width: parent.width
                    height: 112
                    spacing: 14

                    Rectangle {
                        width: 330
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
                                y: 8
                                color: Qt.alpha(root.toneColor(root.headlineTone()), 0.18)
                                border.width: 2
                                border.color: root.toneColor(root.headlineTone())

                                Text {
                                    anchors.centerIn: parent
                                    text: "NET"
                                    color: root.toneColor(root.headlineTone())
                                    font.pixelSize: 15
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
                                    font.pixelSize: 26
                                    minimumPixelSize: 16
                                    fontSizeMode: Text.HorizontalFit
                                    font.bold: true
                                }

                                Text {
                                    width: parent.width
                                    text: root.ifaceValue("name") + (root.ifaceValue("parent").length > 0 ? " on " + root.ifaceValue("parent") : "")
                                    color: root.palette.secondaryText
                                    font.pixelSize: 13
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: root.ifaceValue("status").length > 0 ? root.ifaceValue("status") : "No interface"
                                    color: root.palette.mutedText
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 320
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.panelBorder

                        Grid {
                            anchors.fill: parent
                            anchors.margins: 14
                            columns: 2
                            rowSpacing: 10
                            columnSpacing: 10

                            Repeater {
                                model: [
                                    {"label": "IPv4", "value": root.ifaceValue("ipv4")},
                                    {"label": "Gateway", "value": root.routeValue("gateway")},
                                    {"label": "BSSID", "value": root.ifaceValue("bssid")},
                                    {"label": "Channel", "value": root.ifaceValue("channel") + (root.ifaceValue("band").length > 0 ? " / " + root.ifaceValue("band") : "")}
                                ]

                                delegate: Column {
                                    id: summaryCell

                                    required property var modelData

                                    width: 141
                                    height: 36
                                    spacing: 3

                                    Text {
                                        width: parent.width
                                        text: summaryCell.modelData.label
                                        color: root.palette.mutedText
                                        font.pixelSize: 10
                                        font.bold: true
                                    }

                                    Text {
                                        width: parent.width
                                        text: summaryCell.modelData.value || "-"
                                        color: root.palette.primaryText
                                        font.pixelSize: 12
                                        minimumPixelSize: 9
                                        fontSizeMode: Text.HorizontalFit
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width - 330 - 320 - 28
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.toneColor(root.statusTone)

                        Column {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 7

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
                                maximumLineCount: 2
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
                            {"id": "refresh", "label": "Refresh"},
                            {"id": "rescan", "label": "Rescan"},
                            {"id": "recover", "label": "Recover Wi-Fi"}
                        ]

                        delegate: Rectangle {
                            id: commandButton

                            required property var modelData
                            readonly property bool actionEnabled: !root.runningAction && !root.loading
                            readonly property bool hovered: actionMouse.containsMouse && actionEnabled

                            width: 142
                            height: parent.height
                            radius: 8
                            color: hovered ? root.palette.cardHover : root.palette.cardBackground
                            border.width: 1
                            border.color: commandButton.modelData.id === "recover" ? root.palette.warning : root.palette.panelBorder
                            opacity: actionEnabled ? 1.0 : 0.45

                            Text {
                                anchors.centerIn: parent
                                text: commandButton.modelData.label
                                color: commandButton.modelData.id === "recover" ? root.palette.warning : root.palette.primaryText
                                font.pixelSize: 13
                                font.bold: true
                            }

                            MouseArea {
                                id: actionMouse

                                anchors.fill: parent
                                enabled: parent.actionEnabled
                                hoverEnabled: parent.actionEnabled
                                cursorShape: parent.actionEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (commandButton.modelData.id === "refresh")
                                        root.refreshSnapshot()
                                    else if (commandButton.modelData.id === "rescan")
                                        root.runAction("rescan", "Scanning wireless networks")
                                    else
                                        root.runAction("recover", "Recovering Wi-Fi")
                                }
                            }
                        }
                    }

                    Rectangle {
                        readonly property bool hovered: helpMouse.containsMouse

                        width: 76
                        height: parent.height
                        radius: 8
                        color: hovered ? root.palette.cardHover : root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.panelBorder

                        Text {
                            anchors.centerIn: parent
                            text: "Help"
                            color: root.palette.accent
                            font.pixelSize: 13
                            font.bold: true
                        }

                        MouseArea {
                            id: helpMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.helpDialogVisible = true
                        }
                    }

                    Text {
                        width: parent.width - 532
                        height: parent.height
                        verticalAlignment: Text.AlignVCenter
                        text: root.ifaceValue("media")
                        color: root.palette.mutedText
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }

                Row {
                    width: parent.width
                    height: parent.height - 112 - 46 - 28
                    spacing: 14

                    Rectangle {
                        width: 592
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.panelBorder

                        Column {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10

                            Row {
                                width: parent.width
                                height: 22

                                Text {
                                    width: parent.width - 120
                                    text: "Access Points"
                                    color: root.palette.accent
                                    font.pixelSize: 16
                                    font.bold: true
                                }

                                Text {
                                    width: 120
                                    text: root.filteredScanRows().length + " / " + root.scanRows.length + " seen"
                                    color: root.palette.mutedText
                                    horizontalAlignment: Text.AlignRight
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }

                            Row {
                                width: parent.width
                                height: 30
                                spacing: 8

                                Repeater {
                                    model: [
                                        {"id": "all", "label": "All"},
                                        {"id": "2.4", "label": "2.4 GHz"},
                                        {"id": "5", "label": "5 GHz"},
                                        {"id": "hotspot", "label": "Hotspots"}
                                    ]

                                    delegate: Rectangle {
                                        id: filterButton

                                        required property var modelData
                                        readonly property bool selected: root.scanFilter === filterButton.modelData.id
                                        readonly property bool hovered: filterMouse.containsMouse

                                        width: filterButton.modelData.id === "hotspot" ? 104 : 86
                                        height: parent.height
                                        radius: 7
                                        color: selected ? Qt.alpha(root.palette.accent, 0.18) : (hovered ? root.palette.cardHover : root.palette.panelBackground)
                                        border.width: 1
                                        border.color: selected ? root.palette.accent : root.palette.panelBorder

                                        Text {
                                            anchors.centerIn: parent
                                            text: filterButton.modelData.label + " " + root.scanFilterCount(filterButton.modelData.id)
                                            color: filterButton.selected ? root.palette.accent : root.palette.secondaryText
                                            font.pixelSize: 11
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: filterMouse

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.scanFilter = filterButton.modelData.id
                                        }
                                    }
                                }

                                Rectangle {
                                    readonly property bool actionEnabled: !root.runningAction && !root.loading
                                    readonly property bool hovered: manualJoinMouse.containsMouse && actionEnabled

                                    width: 112
                                    height: parent.height
                                    radius: 7
                                    color: hovered ? root.palette.cardHover : root.palette.cardBackground
                                    border.width: 1
                                    border.color: root.palette.accent
                                    opacity: actionEnabled ? 1.0 : 0.45

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Join Other"
                                        color: root.palette.accent
                                        font.pixelSize: 11
                                        font.bold: true
                                    }

                                    MouseArea {
                                        id: manualJoinMouse

                                        anchors.fill: parent
                                        enabled: parent.actionEnabled
                                        hoverEnabled: parent.actionEnabled
                                        cursorShape: parent.actionEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: root.openManualJoinDialog()
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 28
                                radius: 6
                                color: root.palette.panelBackground

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    Repeater {
                                        model: [
                                            {"label": "SSID", "width": 184},
                                            {"label": "BSSID", "width": 142},
                                            {"label": "CH", "width": 30},
                                            {"label": "BAND", "width": 52},
                                            {"label": "SIG", "width": 38},
                                            {"label": "PIN", "width": 38}
                                        ]

                                        delegate: Text {
                                            id: scanHeaderCell

                                            required property var modelData

                                            width: scanHeaderCell.modelData.width
                                            height: parent.height
                                            verticalAlignment: Text.AlignVCenter
                                            text: scanHeaderCell.modelData.label
                                            color: root.palette.mutedText
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                    }
                                }
                            }

                            Flickable {
                                id: scanFlickable

                                width: parent.width
                                height: parent.height - 100
                                contentHeight: scanColumn.height
                                clip: true

                                Column {
                                    id: scanColumn

                                    width: scanFlickable.width
                                    spacing: 6

                                    Repeater {
                                        model: root.filteredScanRows()

                                        delegate: Rectangle {
                                            id: scanRow

                                            required property var modelData
                                            readonly property bool rowHovered: scanRowMouse.containsMouse
                                            readonly property bool hasCaps: modelData.caps && modelData.caps.length > 0

                                            width: scanColumn.width
                                            height: 38
                                            radius: 6
                                            color: root.sameBssid(scanRow.modelData) ? Qt.alpha(root.palette.success, 0.18) : (rowHovered ? root.palette.cardHover : root.palette.panelBackground)
                                            border.width: 1
                                            border.color: root.sameBssid(scanRow.modelData) ? root.palette.success : (rowHovered ? root.palette.panelBorder : root.palette.frameBorder)

                                            MouseArea {
                                                id: scanRowMouse

                                                anchors.fill: parent
                                                hoverEnabled: scanRow.hasCaps
                                                acceptedButtons: Qt.LeftButton
                                                cursorShape: scanRow.modelData.ssid === "(hidden)" ? Qt.ArrowCursor : Qt.PointingHandCursor
                                                onEntered: root.showFeatureTooltip(scanRow)
                                                onPositionChanged: root.showFeatureTooltip(scanRow)
                                                onExited: root.hideFeatureTooltip()
                                                onClicked: root.openJoinDialog(scanRow.modelData)
                                            }

                                            Row {
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 10
                                                spacing: 8

                                                Text {
                                                    width: 184
                                                    height: parent.height
                                                    verticalAlignment: Text.AlignVCenter
                                                    text: scanRow.modelData.ssid || "-"
                                                    color: root.sameBssid(scanRow.modelData) ? root.palette.success : root.palette.primaryText
                                                    font.pixelSize: 12
                                                    font.bold: root.sameBssid(scanRow.modelData)
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    width: 142
                                                    height: parent.height
                                                    verticalAlignment: Text.AlignVCenter
                                                    text: scanRow.modelData.bssid || "-"
                                                    color: root.palette.secondaryText
                                                    font.pixelSize: 11
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    width: 30
                                                    height: parent.height
                                                    verticalAlignment: Text.AlignVCenter
                                                    text: scanRow.modelData.channel || "-"
                                                    color: root.palette.secondaryText
                                                    font.pixelSize: 11
                                                }

                                                Text {
                                                    width: 52
                                                    height: parent.height
                                                    verticalAlignment: Text.AlignVCenter
                                                    text: scanRow.modelData.band || "-"
                                                    color: scanRow.modelData.band === "5 GHz" ? root.palette.accent : root.palette.secondaryText
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                }

                                                Text {
                                                    width: 38
                                                    height: parent.height
                                                    verticalAlignment: Text.AlignVCenter
                                                    text: scanRow.modelData.signal || "-"
                                                    color: root.toneColor(root.strengthTone(scanRow.modelData.signal))
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                }

                                                Rectangle {
                                                    readonly property bool actionEnabled: !root.runningAction && scanRow.modelData.ssid !== "(hidden)" && scanRow.modelData.bssid && scanRow.modelData.bssid.length > 0
                                                    readonly property bool hovered: pinMouse.containsMouse && actionEnabled

                                                    width: 38
                                                    height: 24
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    radius: 5
                                                    color: root.rowPinned(scanRow.modelData) ? Qt.alpha(root.palette.success, 0.18) : (hovered ? root.palette.cardHover : "transparent")
                                                    border.width: 1
                                                    border.color: root.rowPinned(scanRow.modelData) ? root.palette.success : root.palette.panelBorder
                                                    opacity: actionEnabled ? 1.0 : 0.35

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: root.pinText(scanRow.modelData)
                                                        color: root.rowPinned(scanRow.modelData) ? root.palette.success : root.palette.secondaryText
                                                        font.pixelSize: 9
                                                        font.bold: true
                                                    }

                                                    MouseArea {
                                                        id: pinMouse

                                                        anchors.fill: parent
                                                        enabled: parent.actionEnabled
                                                        hoverEnabled: parent.actionEnabled
                                                        cursorShape: parent.actionEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                        onEntered: root.hideFeatureTooltip()
                                                        onClicked: root.runPinAction(scanRow.modelData)
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
                        width: parent.width - 592 - 14
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.panelBorder

                        Column {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10

                            Row {
                                width: parent.width
                                height: 30
                                spacing: 8

                                Repeater {
                                    model: [
                                        {"id": "events", "label": "Events"},
                                        {"id": "diagnostics", "label": "Diagnostics"},
                                        {"id": "tools", "label": "Tools"},
                                        {"id": "printers", "label": "Printers"}
                                    ]

                                    delegate: Rectangle {
                                        id: rightTabButton

                                        required property var modelData
                                        readonly property bool selected: root.rightPanelTab === modelData.id
                                        readonly property bool hovered: tabMouse.containsMouse

                                        width: rightTabButton.modelData.id === "diagnostics" ? 112 : 74
                                        height: parent.height
                                        radius: 6
                                        color: selected ? Qt.alpha(root.palette.accent, 0.18) : (hovered ? root.palette.cardHover : root.palette.panelBackground)
                                        border.width: 1
                                        border.color: selected ? root.palette.accent : root.palette.frameBorder

                                        Text {
                                            anchors.centerIn: parent
                                            text: rightTabButton.modelData.label
                                            color: rightTabButton.selected ? root.palette.accent : root.palette.secondaryText
                                            font.pixelSize: 12
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: tabMouse

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.rightPanelTab = rightTabButton.modelData.id
                                        }
                                    }
                                }

                            }

                            Flickable {
                                id: logFlickable

                                width: parent.width
                                height: parent.height - 40
                                visible: root.rightPanelTab === "events"
                                contentHeight: logColumn.height
                                clip: true

                                Column {
                                    id: logColumn

                                    width: logFlickable.width
                                    spacing: 6

                                    Repeater {
                                        model: root.logLines

                                        delegate: Rectangle {
                                            id: logRow

                                            required property string modelData

                                            width: logColumn.width
                                            height: Math.max(34, logText.implicitHeight + 16)
                                            radius: 6
                                            color: root.palette.panelBackground
                                            border.width: 1
                                            border.color: logRow.modelData.indexOf("timed out") !== -1 || logRow.modelData.indexOf("DISCONNECTED") !== -1 || logRow.modelData.indexOf("No buffer") !== -1 ? root.palette.warning : root.palette.frameBorder

                                            Text {
                                                id: logText

                                                anchors.fill: parent
                                                anchors.margins: 8
                                                text: logRow.modelData
                                                color: parent.border.color === root.palette.warning ? root.palette.warning : root.palette.secondaryText
                                                font.pixelSize: 10
                                                wrapMode: Text.WordWrap
                                            }
                                        }
                                    }
                                }
                            }

                            Flickable {
                                id: dnsFlickable

                                width: parent.width
                                height: parent.height - 40
                                visible: root.rightPanelTab === "diagnostics"
                                contentHeight: dnsColumn.height
                                clip: true

                                Column {
                                    id: dnsColumn

                                    width: dnsFlickable.width
                                    spacing: 10

                                    Rectangle {
                                        width: parent.width
                                        height: 104
                                        radius: 8
                                        color: root.palette.panelBackground
                                        border.width: 1
                                        border.color: root.toneColor(root.dnsValue("tone"))

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 6

                                            Text {
                                                width: parent.width
                                                text: root.dnsValue("status") || "Diagnostics unavailable"
                                                color: root.toneColor(root.dnsValue("tone"))
                                                font.pixelSize: 16
                                                minimumPixelSize: 12
                                                fontSizeMode: Text.HorizontalFit
                                                font.bold: true
                                            }

                                            Text {
                                                width: parent.width
                                                text: root.dnsValue("summary") || "Run Refresh to load diagnostic checks."
                                                color: root.palette.secondaryText
                                                font.pixelSize: 11
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 3
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                width: parent.width
                                                text: "Resolvers: " + root.dnsResolversText()
                                                color: root.palette.mutedText
                                                font.pixelSize: 10
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    Text {
                                        width: parent.width
                                        text: "Preset checks"
                                        color: root.palette.mutedText
                                        font.pixelSize: 11
                                        font.bold: true
                                    }

                                    Repeater {
                                        model: root.dnsPolicy && root.dnsPolicy.checks ? root.dnsPolicy.checks : []

                                        delegate: Rectangle {
                                            id: dnsCheckRow

                                            required property var modelData

                                            width: dnsColumn.width
                                            height: 76
                                            radius: 6
                                            color: root.palette.panelBackground
                                            border.width: 1
                                            border.color: root.toneColor(root.dnsCheckTone(modelData))

                                            Column {
                                                anchors.fill: parent
                                                anchors.margins: 9
                                                spacing: 4

                                                Row {
                                                    width: parent.width
                                                    height: 18

                                                    Text {
                                                        width: parent.width - 104
                                                        height: parent.height
                                                        text: dnsCheckRow.modelData.host || "-"
                                                        color: root.palette.primaryText
                                                        font.pixelSize: 12
                                                        font.bold: true
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        width: 104
                                                        height: parent.height
                                                        horizontalAlignment: Text.AlignRight
                                                        text: dnsCheckRow.modelData.classification || "-"
                                                        color: root.toneColor(root.dnsCheckTone(dnsCheckRow.modelData))
                                                        font.pixelSize: 10
                                                        font.bold: true
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                Text {
                                                    width: parent.width
                                                    text: root.dnsCheckTarget(dnsCheckRow.modelData)
                                                    color: root.palette.secondaryText
                                                    font.pixelSize: 10
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    width: parent.width
                                                    text: (dnsCheckRow.modelData.rcode || "-") + (dnsCheckRow.modelData.server ? " via " + dnsCheckRow.modelData.server : "")
                                                    color: root.palette.mutedText
                                                    font.pixelSize: 10
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Column {
                                id: toolsColumn

                                width: parent.width
                                height: parent.height - 40
                                visible: root.rightPanelTab === "tools"
                                spacing: 10

                                Row {
                                    width: parent.width
                                    height: 30
                                    spacing: 8

                                    Repeater {
                                        model: [
                                            {"id": "ping", "label": "Ping"},
                                            {"id": "traceroute", "label": "Traceroute"},
                                            {"id": "drill", "label": "Drill"},
                                            {"id": "http", "label": "HTTP"}
                                        ]

                                        delegate: Rectangle {
                                            id: toolSelectButton

                                            required property var modelData
                                            readonly property bool selected: root.selectedTool === modelData.id
                                            readonly property bool hovered: toolSelectMouse.containsMouse

                                            width: modelData.id === "traceroute" ? 104 : 64
                                            height: parent.height
                                            radius: 6
                                            color: selected ? Qt.alpha(root.palette.accent, 0.18) : (hovered ? root.palette.cardHover : root.palette.panelBackground)
                                            border.width: 1
                                            border.color: selected ? root.palette.accent : root.palette.frameBorder
                                            opacity: root.runningAction ? 0.7 : 1.0

                                            Text {
                                                anchors.centerIn: parent
                                                text: toolSelectButton.modelData.label
                                                color: toolSelectButton.selected ? root.palette.accent : root.palette.secondaryText
                                                font.pixelSize: 12
                                                font.bold: true
                                            }

                                            MouseArea {
                                                id: toolSelectMouse

                                                anchors.fill: parent
                                                enabled: !root.runningAction
                                                hoverEnabled: !root.runningAction
                                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: root.selectedTool = toolSelectButton.modelData.id
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 50
                                    radius: 8
                                    color: root.palette.panelBackground
                                    border.width: 1
                                    border.color: root.palette.frameBorder

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 8

                                        Rectangle {
                                            width: parent.width - 106
                                            height: parent.height
                                            radius: 6
                                            color: root.palette.cardBackground
                                            border.width: 1
                                            border.color: toolInput.activeFocus ? root.palette.accent : root.palette.frameBorder

                                            TextInput {
                                                id: toolInput

                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 10
                                                verticalAlignment: TextInput.AlignVCenter
                                                text: root.selectedToolHost()
                                                color: root.palette.primaryText
                                                selectedTextColor: root.palette.frameBackground
                                                selectionColor: root.palette.accent
                                                font.pixelSize: 12
                                                clip: true
                                                onTextChanged: root.setSelectedToolHost(text)
                                                onAccepted: root.runSelectedTool()
                                            }
                                        }

                                        Rectangle {
                                            width: 90
                                            height: parent.height
                                            radius: 6
                                            color: toolRunMouse.containsMouse && !root.runningAction ? root.palette.cardHover : root.palette.cardBackground
                                            border.width: 1
                                            border.color: root.runningAction ? root.palette.frameBorder : root.palette.accent
                                            opacity: root.runningAction ? 0.5 : 1.0

                                            Text {
                                                anchors.centerIn: parent
                                                text: root.selectedToolButtonText()
                                                color: root.palette.accent
                                                font.pixelSize: 12
                                                font.bold: true
                                            }

                                            MouseArea {
                                                id: toolRunMouse

                                                anchors.fill: parent
                                                enabled: !root.runningAction
                                                hoverEnabled: !root.runningAction
                                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: root.runSelectedTool()
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: parent.height - 100
                                    radius: 8
                                    color: root.palette.panelBackground
                                    border.width: 1
                                    border.color: root.selectedToolHasOutput() ? root.toneColor(root.statusTone) : root.palette.frameBorder

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 6

                                        Text {
                                            width: parent.width
                                            text: root.selectedToolHasOutput() ? root.statusMessage : root.selectedToolName() + " output"
                                            color: root.selectedToolHasOutput() ? root.toneColor(root.statusTone) : root.palette.mutedText
                                            font.pixelSize: 12
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Flickable {
                                            width: parent.width
                                            height: parent.height - 24
                                            contentHeight: toolResultText.implicitHeight
                                            clip: true

                                            Text {
                                                id: toolResultText

                                                width: parent.width
                                                text: root.selectedToolHasOutput() ? root.actionDetails : ""
                                                color: root.palette.secondaryText
                                                font.pixelSize: 10
                                                wrapMode: Text.WordWrap
                                            }
                                        }
                                    }
                                }
                            }

                            Flickable {
                                id: printerFlickable

                                width: parent.width
                                height: parent.height - 40
                                visible: root.rightPanelTab === "printers"
                                contentHeight: printerColumn.height
                                clip: true

                                Column {
                                    id: printerColumn

                                    width: printerFlickable.width
                                    spacing: 10

                                    Rectangle {
                                        width: parent.width
                                        height: 86
                                        radius: 8
                                        color: root.palette.panelBackground
                                        border.width: 1
                                        border.color: root.printerList("discovered").length > 0 ? root.palette.success : root.palette.warning

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 6

                                            Text {
                                                width: parent.width
                                                text: root.printerSummary()
                                                color: root.printerList("discovered").length > 0 ? root.palette.success : root.palette.warning
                                                font.pixelSize: 16
                                                font.bold: true
                                            }

                                            Text {
                                                width: parent.width
                                                text: "IPP/mDNS " + root.printerList("discovered").length + " / CUPS " + root.printerList("configured").length + " / URI " + root.printerList("ipp_uris").length
                                                color: root.palette.secondaryText
                                                font.pixelSize: 11
                                                wrapMode: Text.WordWrap
                                            }

                                            Text {
                                                width: parent.width
                                                text: "Tools: avahi-browse " + ((root.printers.available && root.printers.available.avahi_browse) ? "ok" : "missing") + " / ippfind " + ((root.printers.available && root.printers.available.ippfind) ? "ok" : "missing") + " / lpstat " + ((root.printers.available && root.printers.available.lpstat) ? "ok" : "missing")
                                                color: root.palette.mutedText
                                                font.pixelSize: 10
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    Text {
                                        width: parent.width
                                        text: "Discovered printers"
                                        color: root.palette.mutedText
                                        font.pixelSize: 11
                                        font.bold: true
                                    }

                                    Repeater {
                                        model: root.printerList("discovered")

                                        delegate: Rectangle {
                                            id: discoveredPrinterRow

                                            required property var modelData

                                            width: printerColumn.width
                                            height: 92
                                            radius: 6
                                            color: root.palette.panelBackground
                                            border.width: 1
                                            border.color: root.palette.frameBorder

                                            Column {
                                                anchors.fill: parent
                                                anchors.margins: 9
                                                spacing: 5

                                                Row {
                                                    width: parent.width
                                                    height: 18

                                                    Text {
                                                        width: parent.width - 66
                                                        height: parent.height
                                                        text: discoveredPrinterRow.modelData.name || "-"
                                                        color: root.palette.primaryText
                                                        font.pixelSize: 12
                                                        font.bold: true
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        width: 66
                                                        height: parent.height
                                                        horizontalAlignment: Text.AlignRight
                                                        text: discoveredPrinterRow.modelData.protocol || "-"
                                                        color: root.palette.accent
                                                        font.pixelSize: 10
                                                        font.bold: true
                                                    }
                                                }

                                                Text {
                                                    width: parent.width
                                                    text: root.printerAddressText(discoveredPrinterRow.modelData)
                                                    color: root.palette.secondaryText
                                                    font.pixelSize: 10
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    width: parent.width
                                                    text: (discoveredPrinterRow.modelData.type || "Model unknown") + " / " + root.printerCapabilityText(discoveredPrinterRow.modelData)
                                                    color: root.palette.mutedText
                                                    font.pixelSize: 10
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    width: parent.width
                                                    text: discoveredPrinterRow.modelData.admin_url || discoveredPrinterRow.modelData.hostname || "-"
                                                    color: root.palette.mutedText
                                                    font.pixelSize: 10
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        width: parent.width
                                        text: "Configured queues"
                                        color: root.palette.mutedText
                                        font.pixelSize: 11
                                        font.bold: true
                                    }

                                    Repeater {
                                        model: root.printerList("configured")

                                        delegate: Rectangle {
                                            id: configuredPrinterRow

                                            required property var modelData

                                            width: printerColumn.width
                                            height: 58
                                            radius: 6
                                            color: root.palette.panelBackground
                                            border.width: 1
                                            border.color: root.palette.frameBorder

                                            Column {
                                                anchors.fill: parent
                                                anchors.margins: 9
                                                spacing: 5

                                                Text {
                                                    width: parent.width
                                                    text: configuredPrinterRow.modelData.name || "-"
                                                    color: root.palette.primaryText
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    width: parent.width
                                                    text: configuredPrinterRow.modelData.uri || "-"
                                                    color: root.palette.secondaryText
                                                    font.pixelSize: 10
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        width: parent.width
                                        text: "IPP URIs"
                                        color: root.palette.mutedText
                                        font.pixelSize: 11
                                        font.bold: true
                                    }

                                    Repeater {
                                        model: root.printerList("ipp_uris")

                                        delegate: Rectangle {
                                            id: ippUriRow

                                            required property string modelData

                                            width: printerColumn.width
                                            height: 34
                                            radius: 6
                                            color: root.palette.panelBackground
                                            border.width: 1
                                            border.color: root.palette.frameBorder

                                            Text {
                                                anchors.fill: parent
                                                anchors.margins: 9
                                                verticalAlignment: Text.AlignVCenter
                                                text: ippUriRow.modelData
                                                color: root.palette.secondaryText
                                                font.pixelSize: 10
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

            Rectangle {
                width: 356
                height: Math.max(38, featureTooltipLabel.implicitHeight + 16)
                x: root.featureTooltipX
                y: root.featureTooltipY
                z: 1000
                visible: root.featureTooltipVisible
                radius: 6
                color: root.palette.cardBackground
                border.width: 1
                border.color: root.palette.accent

                Text {
                    id: featureTooltipLabel

                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.featureTooltipText
                    color: root.palette.primaryText
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
            }

            Rectangle {
                anchors.fill: parent
                z: 1150
                visible: root.helpDialogVisible
                color: Qt.alpha(root.palette.frameBackground, 0.64)

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.closeHelpDialog()
                }

                Rectangle {
                    width: 560
                    height: 526
                    anchors.centerIn: parent
                    radius: 8
                    color: root.palette.cardBackground
                    border.width: 1
                    border.color: root.palette.accent

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {}
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        Row {
                            width: parent.width
                            height: 28

                            Text {
                                width: parent.width - 38
                                height: parent.height
                                verticalAlignment: Text.AlignVCenter
                                text: "Wi-Fi Capability Terms"
                                color: root.palette.accent
                                font.pixelSize: 17
                                font.bold: true
                            }

                            Rectangle {
                                width: 28
                                height: 28
                                radius: 6
                                color: helpCloseMouse.containsMouse ? root.palette.cardHover : root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.frameBorder

                                Text {
                                    anchors.centerIn: parent
                                    text: "X"
                                    color: root.palette.secondaryText
                                    font.pixelSize: 12
                                    font.bold: true
                                }

                                MouseArea {
                                    id: helpCloseMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.closeHelpDialog()
                                }
                            }
                        }

                        Flickable {
                            width: parent.width
                            height: parent.height - 40
                            contentHeight: helpColumn.height
                            clip: true

                            Column {
                                id: helpColumn

                                width: parent.width
                                spacing: 8

                                Repeater {
                                    model: [
                                        {"term": "RSN", "text": "Modern WPA2/WPA3-style security information. Secured APs usually advertise this."},
                                        {"term": "WPA", "text": "Older WPA security information. Less modern than RSN."},
                                        {"term": "HTCAP", "text": "802.11n high-throughput support. Common on 2.4 GHz and 5 GHz networks."},
                                        {"term": "VHTCAP", "text": "802.11ac very-high-throughput support. Usually a 5 GHz capability."},
                                        {"term": "HECAP / HEOPER", "text": "802.11ax Wi-Fi 6 capability and operating details."},
                                        {"term": "WME", "text": "Wireless multimedia quality-of-service support for voice, video, best effort, and background traffic."},
                                        {"term": "BSSLOAD", "text": "Access-point load information, such as channel utilization or client capacity hints."},
                                        {"term": "APCHANREP", "text": "Neighbor channel reports that help clients discover nearby APs and roam."},
                                        {"term": "VHTOPMODE", "text": "802.11ac operating-mode information for the AP."},
                                        {"term": "VHTPWRENV", "text": "Transmit-power envelope information for 802.11ac operation."},
                                        {"term": "MU_EDCA_PARAM_SET", "text": "Wi-Fi 6 traffic-scheduling parameters for multi-user behavior."},
                                        {"term": "WPS", "text": "Wi-Fi Protected Setup onboarding support. Convenient, but not a feature to rely on for security."}
                                    ]

                                    delegate: Rectangle {
                                        id: helpTermRow

                                        required property var modelData

                                        width: helpColumn.width
                                        height: Math.max(42, helpTermBody.implicitHeight + 16)
                                        radius: 6
                                        color: root.palette.panelBackground
                                        border.width: 1
                                        border.color: root.palette.frameBorder

                                        Row {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 10

                                            Text {
                                                width: 132
                                                height: parent.height
                                                verticalAlignment: Text.AlignTop
                                                text: helpTermRow.modelData.term
                                                color: root.palette.primaryText
                                                font.pixelSize: 12
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                id: helpTermBody

                                                width: parent.width - 142
                                                text: helpTermRow.modelData.text
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

            Rectangle {
                anchors.fill: parent
                z: 1200
                visible: root.joinDialogVisible
                color: Qt.alpha(root.palette.frameBackground, 0.64)

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.closeJoinDialog()
                }

                Rectangle {
                    width: 360
                    height: root.joinSsidEditable ? 294 : 238
                    anchors.centerIn: parent
                    radius: 8
                    color: root.palette.cardBackground
                    border.width: 1
                    border.color: root.palette.accent

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {}
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        Text {
                            width: parent.width
                            text: root.joinSsidEditable ? "Join Other Wi-Fi" : "Join Wi-Fi"
                            color: root.palette.accent
                            font.pixelSize: 17
                            font.bold: true
                        }

                        Column {
                            width: parent.width
                            visible: !root.joinSsidEditable
                            spacing: 4

                            Text {
                                width: parent.width
                                text: root.joinSsid
                                color: root.palette.primaryText
                                font.pixelSize: 14
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: root.joinBssid
                                color: root.palette.mutedText
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: root.joinSsidEditable ? 38 : 0
                            visible: root.joinSsidEditable
                            radius: 6
                            color: root.palette.panelBackground
                            border.width: 1
                            border.color: joinSsidInput.activeFocus ? root.palette.accent : root.palette.frameBorder

                            TextInput {
                                id: joinSsidInput

                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                text: root.joinSsid
                                color: root.palette.primaryText
                                selectedTextColor: root.palette.frameBackground
                                selectionColor: root.palette.accent
                                font.pixelSize: 13
                                clip: true
                                focus: root.joinDialogVisible && root.joinSsidEditable
                                onTextChanged: root.joinSsid = text
                                onAccepted: joinPasswordInput.forceActiveFocus()
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 38
                            radius: 6
                            color: root.palette.panelBackground
                            border.width: 1
                            border.color: joinPasswordInput.activeFocus ? root.palette.accent : root.palette.frameBorder

                            TextInput {
                                id: joinPasswordInput

                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                text: root.joinPassword
                                echoMode: TextInput.Password
                                color: root.palette.primaryText
                                selectedTextColor: root.palette.frameBackground
                                selectionColor: root.palette.accent
                                font.pixelSize: 13
                                clip: true
                                focus: root.joinDialogVisible && !root.joinSsidEditable
                                onTextChanged: root.joinPassword = text
                                onAccepted: root.runJoin()
                            }
                        }

                        Row {
                            width: parent.width
                            height: 38
                            spacing: 10

                            Rectangle {
                                width: (parent.width - 10) / 2
                                height: parent.height
                                radius: 6
                                color: joinCancelMouse.containsMouse ? root.palette.cardHover : root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.frameBorder

                                Text {
                                    anchors.centerIn: parent
                                    text: "Cancel"
                                    color: root.palette.secondaryText
                                    font.pixelSize: 12
                                    font.bold: true
                                }

                                MouseArea {
                                    id: joinCancelMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.closeJoinDialog()
                                }
                            }

                            Rectangle {
                                width: (parent.width - 10) / 2
                                height: parent.height
                                radius: 6
                                color: joinConfirmMouse.containsMouse ? root.palette.cardHover : Qt.alpha(root.palette.accent, 0.14)
                                border.width: 1
                                border.color: root.palette.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: "Join"
                                    color: root.palette.accent
                                    font.pixelSize: 12
                                    font.bold: true
                                }

                                MouseArea {
                                    id: joinConfirmMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.runJoin()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
