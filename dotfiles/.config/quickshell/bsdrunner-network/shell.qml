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
    property string activeActionLabel: ""
    property string lookupName: "freebsd.org"
    property var interfaceInfo: ({})
    property var routeInfo: ({})
    property var tools: ({})
    property var scanRows: []
    property var logLines: []
    property var dnsPolicy: ({})
    property var lastResult: ({})
    property string rightPanelTab: "events"
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

    function runAction(actionId, label, actionArg) {
        if (runningAction)
            return
        activeActionId = actionId
        activeActionArg = actionArg || ""
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
        activeActionId = ""
        activeActionArg = ""
        activeActionLabel = ""
        if (completedActionId !== "drill")
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

        command: ["sh", themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-network-backend.sh", root.activeActionId, root.activeActionArg]
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
                            {"id": "recover", "label": "Recover Wi-Fi"}
                        ]

                        delegate: Rectangle {
                            id: commandButton

                            required property var modelData
                            readonly property bool actionEnabled: !root.runningAction && !root.loading
                            readonly property bool hovered: actionMouse.containsMouse && actionEnabled

                            width: 154
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
                                    else
                                        root.runAction("recover", "Recovering Wi-Fi")
                                }
                            }
                        }
                    }

                    Text {
                        width: parent.width - 318
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
                                    text: root.scanRows.length + " seen"
                                    color: root.palette.mutedText
                                    horizontalAlignment: Text.AlignRight
                                    font.pixelSize: 11
                                    font.bold: true
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
                                            {"label": "SSID", "width": 150},
                                            {"label": "BSSID", "width": 122},
                                            {"label": "CH", "width": 34},
                                            {"label": "BAND", "width": 56},
                                            {"label": "SIG", "width": 42},
                                            {"label": "CAPS", "width": 96}
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
                                height: parent.height - 60
                                contentHeight: scanColumn.height
                                clip: true

                                Column {
                                    id: scanColumn

                                    width: scanFlickable.width
                                    spacing: 6

                                    Repeater {
                                        model: root.scanRows

                                        delegate: Rectangle {
                                            id: scanRow

                                            required property var modelData

                                            width: scanColumn.width
                                            height: 38
                                            radius: 6
                                            color: root.sameBssid(scanRow.modelData) ? Qt.alpha(root.palette.success, 0.18) : root.palette.panelBackground
                                            border.width: 1
                                            border.color: root.sameBssid(scanRow.modelData) ? root.palette.success : root.palette.frameBorder

                                            Row {
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 10
                                                spacing: 8

                                                Text {
                                                    width: 150
                                                    height: parent.height
                                                    verticalAlignment: Text.AlignVCenter
                                                    text: scanRow.modelData.ssid || "-"
                                                    color: root.sameBssid(scanRow.modelData) ? root.palette.success : root.palette.primaryText
                                                    font.pixelSize: 12
                                                    font.bold: root.sameBssid(scanRow.modelData)
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    width: 122
                                                    height: parent.height
                                                    verticalAlignment: Text.AlignVCenter
                                                    text: scanRow.modelData.bssid || "-"
                                                    color: root.palette.secondaryText
                                                    font.pixelSize: 11
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    width: 34
                                                    height: parent.height
                                                    verticalAlignment: Text.AlignVCenter
                                                    text: scanRow.modelData.channel || "-"
                                                    color: root.palette.secondaryText
                                                    font.pixelSize: 11
                                                }

                                                Text {
                                                    width: 56
                                                    height: parent.height
                                                    verticalAlignment: Text.AlignVCenter
                                                    text: scanRow.modelData.band || "-"
                                                    color: scanRow.modelData.band === "5 GHz" ? root.palette.accent : root.palette.secondaryText
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                }

                                                Text {
                                                    width: 42
                                                    height: parent.height
                                                    verticalAlignment: Text.AlignVCenter
                                                    text: scanRow.modelData.signal || "-"
                                                    color: root.toneColor(root.strengthTone(scanRow.modelData.signal))
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                }

                                                Text {
                                                    width: 96
                                                    height: parent.height
                                                    verticalAlignment: Text.AlignVCenter
                                                    text: scanRow.modelData.caps || "-"
                                                    color: root.palette.mutedText
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
                                        {"id": "dns", "label": "Tools"}
                                    ]

                                    delegate: Rectangle {
                                        id: rightTabButton

                                        required property var modelData
                                        readonly property bool selected: root.rightPanelTab === modelData.id
                                        readonly property bool hovered: tabMouse.containsMouse

                                        width: 86
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

                                Text {
                                    width: parent.width - 188
                                    height: parent.height
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignRight
                                    text: root.rightPanelTab === "dns" ? root.dnsValue("status") : root.logLines.length + " lines"
                                    color: root.rightPanelTab === "dns" ? root.toneColor(root.dnsValue("tone")) : root.palette.mutedText
                                    font.pixelSize: 11
                                    font.bold: true
                                    elide: Text.ElideRight
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
                                visible: root.rightPanelTab === "dns"
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

                                    Rectangle {
                                        width: parent.width
                                        height: 82
                                        radius: 8
                                        color: root.palette.panelBackground
                                        border.width: 1
                                        border.color: root.palette.frameBorder

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            spacing: 8

                                            Text {
                                                width: parent.width
                                                text: "DNS lookup"
                                                color: root.palette.accent
                                                font.pixelSize: 12
                                                font.bold: true
                                            }

                                            Row {
                                                width: parent.width
                                                height: 34
                                                spacing: 8

                                                Rectangle {
                                                    width: parent.width - 82
                                                    height: parent.height
                                                    radius: 6
                                                    color: root.palette.cardBackground
                                                    border.width: 1
                                                    border.color: lookupInput.activeFocus ? root.palette.accent : root.palette.frameBorder

                                                    TextInput {
                                                        id: lookupInput

                                                        anchors.fill: parent
                                                        anchors.leftMargin: 10
                                                        anchors.rightMargin: 10
                                                        verticalAlignment: TextInput.AlignVCenter
                                                        text: root.lookupName
                                                        color: root.palette.primaryText
                                                        selectedTextColor: root.palette.frameBackground
                                                        selectionColor: root.palette.accent
                                                        font.pixelSize: 12
                                                        clip: true
                                                        onTextChanged: root.lookupName = text
                                                        onAccepted: root.runLookup()
                                                    }
                                                }

                                                Rectangle {
                                                    width: 74
                                                    height: parent.height
                                                    radius: 6
                                                    color: lookupMouse.containsMouse && !root.runningAction ? root.palette.cardHover : root.palette.cardBackground
                                                    border.width: 1
                                                    border.color: root.runningAction ? root.palette.frameBorder : root.palette.accent
                                                    opacity: root.runningAction ? 0.5 : 1.0

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "Drill"
                                                        color: root.palette.accent
                                                        font.pixelSize: 12
                                                        font.bold: true
                                                    }

                                                    MouseArea {
                                                        id: lookupMouse

                                                        anchors.fill: parent
                                                        enabled: !root.runningAction
                                                        hoverEnabled: !root.runningAction
                                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                        onClicked: root.runLookup()
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: 132
                                        visible: root.actionDetails.length > 0
                                        radius: 8
                                        color: root.palette.panelBackground
                                        border.width: 1
                                        border.color: root.toneColor(root.statusTone)

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            spacing: 6

                                            Text {
                                                width: parent.width
                                                text: root.statusMessage
                                                color: root.toneColor(root.statusTone)
                                                font.pixelSize: 12
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            Flickable {
                                                width: parent.width
                                                height: parent.height - 24
                                                contentHeight: lookupResultText.implicitHeight
                                                clip: true

                                                Text {
                                                    id: lookupResultText

                                                    width: parent.width
                                                    text: root.actionDetails
                                                    color: root.palette.secondaryText
                                                    font.pixelSize: 10
                                                    wrapMode: Text.WordWrap
                                                }
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
                        }
                    }
                }
            }
        }
    }
}
