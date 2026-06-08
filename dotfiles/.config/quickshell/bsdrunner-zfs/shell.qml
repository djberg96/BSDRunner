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
    readonly property var snapshotPresets: ["manual", "before-update", "experiment"]
    readonly property var datasetNamePresets: ["jails", "data"]
    readonly property var datasetCompressionOptions: ["inherit", "lz4", "zstd", "off"]
    readonly property var datasetAtimeOptions: ["inherit", "off", "on"]
    readonly property var datasetRecordsizeOptions: ["inherit", "16K", "32K", "64K", "128K", "1M"]
    property bool loading: false
    property bool runningAction: false
    property bool datasetDialogOpen: false
    property string statusTone: "info"
    property string statusMessage: "Loading ZFS status..."
    property string actionDetails: ""
    property string activeActionId: ""
    property string activeActionArg1: ""
    property string activeActionArg2: ""
    property string activeActionLabel: ""
    property string activeActionArg3: ""
    property string activeActionArg4: ""
    property string activeActionArg5: ""
    property string activeActionArg6: ""
    property string activeActionArg7: ""
    property string activeActionArg8: ""
    property string pendingActionId: ""
    property string pendingActionLabel: ""
    property string pendingActionDescription: ""
    property bool pendingSnapshotRecursive: false
    property string snapshotName: ""
    property string datasetChildName: ""
    property string datasetMountpoint: ""
    property string datasetQuota: ""
    property string datasetReservation: ""
    property string datasetCompression: "inherit"
    property string datasetAtime: "inherit"
    property string datasetRecordsize: "inherit"
    property string datasetToSelectAfterRefresh: ""
    property string selectedDatasetName: ""
    property string selectedSnapshotName: ""
    property string centerPaneMode: "details"
    property string rightPaneMode: "dataset"
    property var pools: []
    property var datasets: []
    property var snapshots: []
    property bool hasZfs: false
    property string lastResultTone: "info"
    property string lastResultMessage: "No ZFS action has run yet."
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

    readonly property var selectedDataset: findByName(datasets, selectedDatasetName)
    readonly property var selectedSnapshot: findByName(snapshots, selectedSnapshotName)
    readonly property var visibleSnapshots: snapshotsForDataset(selectedDatasetName)

    function findByName(list, name) {
        for (var i = 0; i < list.length; i += 1) {
            if (list[i].name === name)
                return list[i]
        }
        return null
    }

    function isPoolDataset(datasetName) {
        return !!findByName(pools, datasetName)
    }

    function snapshotsForDataset(datasetName) {
        if (!datasetName)
            return snapshots

        var filtered = []
        for (var i = 0; i < snapshots.length; i += 1) {
            if (snapshots[i].dataset === datasetName)
                filtered.push(snapshots[i])
        }
        return filtered
    }

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

    function healthTone() {
        if (!hasZfs)
            return "error"
        if (pools.length === 0)
            return "warning"
        for (var i = 0; i < pools.length; i += 1) {
            if ((pools[i].health || "").toLowerCase() !== "online")
                return "warning"
        }
        return "success"
    }

    function headline() {
        if (!hasZfs)
            return "ZFS Unavailable"
        if (pools.length === 0)
            return "No Pools"
        return healthTone() === "success" ? "Pools Online" : "Check Pool"
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

    function selectedDatasetDetail() {
        if (!selectedDataset)
            return "Select a dataset to create snapshots or inspect details."
        return selectedDataset.used + " used / " + selectedDataset.avail + " free"
    }

    function selectedDatasetCanHaveChildren() {
        return selectedDataset && selectedDataset.type === "filesystem"
    }

    function datasetFullName() {
        if (!selectedDatasetName || !datasetChildName)
            return ""
        return selectedDatasetName + "/" + datasetChildName
    }

    function optionIsSet(value) {
        return value && value.length > 0 && value !== "inherit"
    }

    function datasetOptionsSummary() {
        var options = []
        if (optionIsSet(datasetMountpoint))
            options.push("mountpoint=" + datasetMountpoint)
        if (optionIsSet(datasetQuota))
            options.push("quota=" + datasetQuota)
        if (optionIsSet(datasetReservation))
            options.push("reservation=" + datasetReservation)
        if (optionIsSet(datasetCompression))
            options.push("compression=" + datasetCompression)
        if (optionIsSet(datasetAtime))
            options.push("atime=" + datasetAtime)
        if (optionIsSet(datasetRecordsize))
            options.push("recordsize=" + datasetRecordsize)
        return options.length > 0 ? "\n\nOptions: " + options.join(", ") : "\n\nOptions inherit from the parent."
    }

    function resetDatasetOptions() {
        datasetMountpoint = ""
        datasetQuota = ""
        datasetReservation = ""
        datasetCompression = "inherit"
        datasetAtime = "inherit"
        datasetRecordsize = "inherit"
    }

    function selectedDatasetSnapshotCount() {
        return visibleSnapshots.length
    }

    function latestSnapshot() {
        if (visibleSnapshots.length === 0)
            return null
        return visibleSnapshots[visibleSnapshots.length - 1]
    }

    function ensureSnapshotSelection() {
        if (rightPaneMode !== "snapshots") {
            selectedSnapshotName = ""
            return
        }

        if (visibleSnapshots.length > 0 && (!selectedSnapshotName || !findByName(visibleSnapshots, selectedSnapshotName)))
            selectedSnapshotName = visibleSnapshots[visibleSnapshots.length - 1].name
        else if (visibleSnapshots.length === 0)
            selectedSnapshotName = ""
    }

    function showDatasetDetails() {
        centerPaneMode = "details"
        rightPaneMode = "dataset"
        selectedSnapshotName = ""
    }

    function showSnapshots() {
        if (!selectedDatasetName)
            return
        centerPaneMode = "snapshots"
        rightPaneMode = "snapshots"
        ensureSnapshotSelection()
    }

    function propertyValue(value) {
        if (!value || value === "-" || value === "none")
            return "None"
        return value
    }

    function encryptionEnabled(dataset) {
        return dataset && dataset.encryption && dataset.encryption !== "off"
    }

    function encryptionLabel(dataset) {
        if (!dataset)
            return "No dataset selected"
        if (!encryptionEnabled(dataset))
            return "Unencrypted"
        if ((dataset.keystatus || "").toLowerCase() === "available")
            return "Encrypted / Key Loaded"
        if ((dataset.keystatus || "").toLowerCase() === "unavailable")
            return "Encrypted / Key Unloaded"
        return "Encrypted"
    }

    function encryptionTone(dataset) {
        if (!dataset || !encryptionEnabled(dataset))
            return "info"
        return (dataset.keystatus || "").toLowerCase() === "available" ? "success" : "warning"
    }

    function selectedSnapshotDetail() {
        if (!selectedSnapshot)
            return "Select a snapshot for rollback or deletion."
        return selectedSnapshot.created + " | " + selectedSnapshot.used + " used"
    }

    function createSnapshotLabel() {
        return snapshotName && snapshotName.length > 0 ? snapshotName : "auto timestamp"
    }

    function requestAction(actionId, label, description) {
        if (runningAction)
            return
        pendingActionId = actionId
        pendingActionLabel = label
        pendingActionDescription = description
        pendingSnapshotRecursive = false
    }

    function openCreateDatasetDialog() {
        if (!selectedDatasetCanHaveChildren() || runningAction)
            return
        datasetDialogOpen = true
        datasetChildName = ""
        resetDatasetOptions()
        clearPendingAction()
    }

    function requestCreateDataset() {
        if (!selectedDatasetCanHaveChildren() || !datasetChildName || runningAction)
            return
        datasetDialogOpen = false
        requestAction(
            "create-dataset",
            "Create dataset",
            "Create " + datasetFullName() + "?" + datasetOptionsSummary()
        )
    }

    function clearPendingAction() {
        pendingActionId = ""
        pendingActionLabel = ""
        pendingActionDescription = ""
        pendingSnapshotRecursive = false
    }

    function confirmPendingAction() {
        if (!pendingActionId)
            return

        activeActionId = pendingActionId
        activeActionLabel = pendingActionLabel
        if (pendingActionId === "create-snapshot") {
            activeActionArg1 = selectedDatasetName
            activeActionArg2 = snapshotName
            activeActionArg3 = pendingSnapshotRecursive ? "recursive" : ""
            activeActionArg4 = ""
            activeActionArg5 = ""
            activeActionArg6 = ""
            activeActionArg7 = ""
            activeActionArg8 = ""
        } else if (pendingActionId === "create-dataset") {
            activeActionArg1 = selectedDatasetName
            activeActionArg2 = datasetChildName
            activeActionArg3 = datasetMountpoint
            activeActionArg4 = datasetQuota
            activeActionArg5 = datasetReservation
            activeActionArg6 = datasetCompression
            activeActionArg7 = datasetAtime
            activeActionArg8 = datasetRecordsize
        } else {
            activeActionArg1 = selectedSnapshotName
            activeActionArg2 = ""
            activeActionArg3 = ""
            activeActionArg4 = ""
            activeActionArg5 = ""
            activeActionArg6 = ""
            activeActionArg7 = ""
            activeActionArg8 = ""
        }
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
            statusMessage = "The ZFS backend returned invalid JSON."
            actionDetails = stderrText || text || ""
            return
        }

        if (exitCode !== 0 || !payload.ok) {
            statusTone = "error"
            statusMessage = payload.message || stderrText || "Unable to load ZFS status."
            return
        }

        hasZfs = payload.tools ? !!payload.tools.zfs : false
        pools = payload.pools || []
        datasets = payload.datasets || []
        snapshots = payload.snapshots || []
        lastResultTone = payload.last_result ? payload.last_result.tone || "info" : "info"
        lastResultMessage = payload.last_result ? payload.last_result.message || payload.message : payload.message
        lastResultTimestamp = payload.last_result ? payload.last_result.timestamp || "" : ""
        statusTone = lastResultTone
        statusMessage = payload.message || "Loaded ZFS status."

        if (datasetToSelectAfterRefresh.length > 0 && findByName(datasets, datasetToSelectAfterRefresh)) {
            selectedDatasetName = datasetToSelectAfterRefresh
            datasetToSelectAfterRefresh = ""
        } else if ((!selectedDatasetName || !findByName(datasets, selectedDatasetName)) && datasets.length > 0) {
            selectedDatasetName = datasets[0].name
        }

        ensureSnapshotSelection()
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
            statusTone = (activeActionId === "create-snapshot" || activeActionId === "create-dataset") ? "success" : "warning"
            statusMessage = payload.message || "ZFS action completed."
            actionDetails = payload.details || ""
            if (activeActionId === "create-snapshot")
                snapshotName = ""
            if (activeActionId === "create-dataset") {
                datasetToSelectAfterRefresh = activeActionArg1 + "/" + activeActionArg2
                datasetChildName = ""
                resetDatasetOptions()
                centerPaneMode = "details"
                rightPaneMode = "dataset"
            }
        } else if (payload) {
            statusTone = "error"
            statusMessage = payload.message || "ZFS action failed."
            actionDetails = payload.details || stderrText || ""
        } else {
            statusTone = "error"
            statusMessage = "The ZFS backend returned invalid JSON."
            actionDetails = stderrText || text || ""
        }

        activeActionId = ""
        activeActionArg1 = ""
        activeActionArg2 = ""
        activeActionArg3 = ""
        activeActionArg4 = ""
        activeActionArg5 = ""
        activeActionArg6 = ""
        activeActionArg7 = ""
        activeActionArg8 = ""
        activeActionLabel = ""
        refreshSnapshot()
    }

    Component.onCompleted: refreshSnapshot()

    Process {
        id: snapshotProcess
        property var controller: root

        command: ["sh", themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-zfs-backend.sh", "snapshot"]
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

        command: ["sh", themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-zfs-backend.sh", root.activeActionId, root.activeActionArg1, root.activeActionArg2, root.activeActionArg3, root.activeActionArg4, root.activeActionArg5, root.activeActionArg6, root.activeActionArg7, root.activeActionArg8]
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
        title: "BSDRunner ZFS"
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
                    height: 108
                    spacing: 14

                    Rectangle {
                        width: 320
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.toneColor(root.healthTone())

                        Row {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 14

                            Rectangle {
                                width: 54
                                height: 54
                                radius: 27
                                y: 7
                                color: Qt.alpha(root.toneColor(root.healthTone()), 0.18)
                                border.width: 2
                                border.color: root.toneColor(root.healthTone())

                                Text {
                                    anchors.centerIn: parent
                                    text: "ZFS"
                                    color: root.toneColor(root.healthTone())
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
                                    font.pixelSize: 27
                                    minimumPixelSize: 18
                                    fontSizeMode: Text.HorizontalFit
                                    font.bold: true
                                }

                                Text {
                                    width: parent.width
                                    text: root.pools.length + " pool(s), " + root.datasets.length + " dataset(s)"
                                    color: root.palette.secondaryText
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Text {
                                    width: parent.width
                                    text: root.snapshots.length + " recent snapshot(s)"
                                    color: root.palette.mutedText
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: poolSummaryCard

                        readonly property int visiblePoolCount: root.pools.length > 0 ? Math.min(root.pools.length, 2) : 1

                        width: 430
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.panelBorder

                        Row {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10

                            Repeater {
                                model: root.pools.length > 0 ? root.pools.slice(0, 2) : [{"name": "No pool", "size": "--", "free": "--", "health": "--"}]

                                delegate: Rectangle {
                                    required property var modelData

                                    width: Math.floor((poolSummaryCard.width - 28 - 176 - 8 - (poolSummaryCard.visiblePoolCount * 10)) / poolSummaryCard.visiblePoolCount)
                                    height: 80
                                    radius: 8
                                    color: root.palette.panelBackground
                                    border.width: 1
                                    border.color: (modelData.health || "").toLowerCase() === "online" ? root.palette.success : root.palette.warning

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 9
                                        spacing: 4

                                        Text {
                                            width: parent.width
                                            text: modelData.name
                                            color: root.palette.primaryText
                                            font.pixelSize: 13
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: parent.width
                                            text: modelData.health
                                            color: (modelData.health || "").toLowerCase() === "online" ? root.palette.success : root.palette.warning
                                            font.pixelSize: 12
                                            font.bold: true
                                        }

                                        Text {
                                            width: parent.width
                                            text: modelData.free + " free"
                                            color: root.palette.mutedText
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: 84
                                height: 80
                                radius: 8
                                color: refreshMouse.containsMouse ? root.palette.cardHover : root.palette.panelBackground
                                border.width: 1
                                border.color: root.loading ? root.palette.accent : root.palette.panelBorder
                                opacity: !root.runningAction ? 1 : 0.45

                                Text {
                                    anchors.centerIn: parent
                                    width: parent.width - 10
                                    text: root.loading ? "Refreshing" : "Refresh"
                                    color: root.loading ? root.palette.accent : root.palette.secondaryText
                                    font.pixelSize: 13
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    id: refreshMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !root.loading && !root.runningAction
                                    onClicked: root.refreshSnapshot()
                                }
                            }

                            Rectangle {
                                width: 84
                                height: 80
                                radius: 8
                                color: snapshotsTopMouse.containsMouse ? root.palette.cardHover : root.palette.panelBackground
                                border.width: 1
                                border.color: root.rightPaneMode === "snapshots" ? root.palette.accent : root.palette.panelBorder
                                opacity: root.selectedDatasetName && !root.runningAction ? 1 : 0.45

                                Text {
                                    anchors.centerIn: parent
                                    width: parent.width - 10
                                    text: "Snapshots"
                                    color: root.rightPaneMode === "snapshots" ? root.palette.accent : root.palette.secondaryText
                                    font.pixelSize: 12
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    id: snapshotsTopMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: root.selectedDatasetName ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    enabled: root.selectedDatasetName && !root.runningAction
                                    onClicked: root.showSnapshots()
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width - 320 - 430 - 28
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
                    height: parent.height - 122
                    spacing: 14

                    Rectangle {
                        width: 320
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.panelBorder

                        Column {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10

                            Text {
                                text: "Datasets"
                                color: root.palette.accent
                                font.pixelSize: 15
                                font.bold: true
                            }

                            ListView {
                                id: datasetList

                                width: parent.width
                                height: parent.height - 30
                                clip: true
                                model: root.datasets
                                spacing: 6

                                delegate: Rectangle {
                                    id: datasetRow

                                    required property var modelData
                                    readonly property bool selected: root.selectedDatasetName === modelData.name

                                    width: datasetList.width
                                    height: 52
                                    radius: 8
                                    color: selected ? Qt.alpha(root.palette.accent, 0.16) : root.palette.panelBackground
                                    border.width: 1
                                    border.color: selected ? root.palette.accent : root.palette.frameBorder

                                    Text {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.topMargin: 7
                                        anchors.rightMargin: 8
                                        visible: root.isPoolDataset(datasetRow.modelData.name)
                                        text: "Pool"
                                        color: datasetRow.selected ? root.palette.accent : root.palette.secondaryText
                                        font.pixelSize: 10
                                        font.bold: true
                                    }

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        anchors.rightMargin: root.isPoolDataset(datasetRow.modelData.name) ? 44 : 8
                                        spacing: 2

                                        Text {
                                            width: parent.width
                                            text: modelData.name
                                            color: root.palette.primaryText
                                            font.pixelSize: 15
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: parent.width
                                            text: modelData.used + " used | " + modelData.mountpoint
                                            color: root.palette.mutedText
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        z: 10
                                        width: datasetRow.width
                                        height: datasetRow.height
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.selectedDatasetName = datasetRow.modelData.name
                                            root.showDatasetDetails()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 360
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.panelBorder

                        Column {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10

                            Text {
                                text: root.centerPaneMode === "snapshots" ? "Snapshots" : "Dataset Details"
                                color: root.palette.accent
                                font.pixelSize: 15
                                font.bold: true
                            }

                            ListView {
                                id: snapshotList

                                visible: root.centerPaneMode === "snapshots"
                                width: parent.width
                                height: visible ? parent.height - 30 : 0
                                clip: true
                                model: root.visibleSnapshots
                                spacing: 8

                                delegate: Rectangle {
                                    id: snapshotRow

                                    required property var modelData
                                    readonly property bool selected: root.selectedSnapshotName === modelData.name

                                    width: snapshotList.width
                                    height: 70
                                    radius: 8
                                    color: selected ? Qt.alpha(root.palette.warning, 0.15) : root.palette.panelBackground
                                    border.width: 1
                                    border.color: selected ? root.palette.warning : root.palette.frameBorder

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 4

                                        Text {
                                            width: parent.width
                                            text: modelData.snapshot
                                            color: root.palette.primaryText
                                            font.pixelSize: 13
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: parent.width
                                            text: modelData.created
                                            color: root.palette.secondaryText
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: parent.width
                                            text: modelData.used + " used | " + modelData.refer + " referenced"
                                            color: root.palette.mutedText
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        z: 10
                                        width: snapshotRow.width
                                        height: snapshotRow.height
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selectedSnapshotName = snapshotRow.modelData.name
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                visible: root.centerPaneMode !== "snapshots"
                                height: visible ? 76 : 0
                                radius: 8
                                color: Qt.alpha(root.toneColor(root.encryptionTone(root.selectedDataset)), 0.12)
                                border.width: 1
                                border.color: root.toneColor(root.encryptionTone(root.selectedDataset))

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 9
                                    spacing: 5

                                    Item {
                                        width: parent.width
                                        height: 28

                                        Text {
                                            id: encryptionStatus

                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: root.encryptionLabel(root.selectedDataset)
                                            color: root.toneColor(root.encryptionTone(root.selectedDataset))
                                            font.pixelSize: 12
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            anchors.left: parent.left
                                            anchors.right: encryptionStatus.left
                                            anchors.rightMargin: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: root.selectedDataset ? root.selectedDataset.name : "No dataset selected"
                                            color: root.palette.primaryText
                                            font.pixelSize: 20
                                            minimumPixelSize: 14
                                            fontSizeMode: Text.HorizontalFit
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Text {
                                        width: parent.width
                                        text: root.selectedDataset ? root.selectedDataset.type + " | " + root.propertyValue(root.selectedDataset.mountpoint) : "Select a dataset from the left."
                                        color: root.palette.mutedText
                                        font.pixelSize: 13
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                visible: root.centerPaneMode !== "snapshots"
                                height: visible ? 146 : 0
                                radius: 8
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.frameBorder

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 2

                                    Text {
                                        text: "Storage"
                                        color: root.palette.accent
                                        font.pixelSize: 15
                                        font.bold: true
                                    }

                                    Repeater {
                                        model: root.selectedDataset ? [
                                            {"label": "Used", "value": root.selectedDataset.used},
                                            {"label": "Available", "value": root.selectedDataset.avail},
                                            {"label": "Referenced", "value": root.selectedDataset.refer},
                                            {"label": "Snapshots", "value": root.selectedDatasetSnapshotCount().toString()},
                                            {"label": "Mountpoint", "value": root.propertyValue(root.selectedDataset.mountpoint)}
                                        ] : [
                                            {"label": "Dataset", "value": "None selected"}
                                        ]

                                        delegate: Item {
                                            required property var modelData

                                            width: parent.width
                                            height: 18

                                            Text {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 92
                                                text: modelData.label
                                                color: root.palette.mutedText
                                                font.pixelSize: 13
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                anchors.left: parent.left
                                                anchors.leftMargin: 102
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelData.value
                                                color: root.palette.primaryText
                                                font.pixelSize: 14
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                visible: root.centerPaneMode !== "snapshots"
                                height: visible ? parent.height - 30 - 76 - 146 - 16 : 0
                                radius: 8
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.frameBorder

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 2

                                    Text {
                                        text: "Encryption Properties"
                                        color: root.palette.accent
                                        font.pixelSize: 15
                                        font.bold: true
                                    }

                                    Repeater {
                                        model: root.selectedDataset ? [
                                            {"label": "Encryption", "value": root.propertyValue(root.selectedDataset.encryption)},
                                            {"label": "Key Status", "value": root.propertyValue(root.selectedDataset.keystatus)},
                                            {"label": "Key Format", "value": root.propertyValue(root.selectedDataset.keyformat)},
                                            {"label": "Key Location", "value": root.propertyValue(root.selectedDataset.keylocation)},
                                            {"label": "Encryption Root", "value": root.propertyValue(root.selectedDataset.encryptionroot)},
                                            {"label": "PBKDF2 Iters", "value": root.propertyValue(root.selectedDataset.pbkdf2iters)}
                                        ] : [
                                            {"label": "Encryption", "value": "None selected"}
                                        ]

                                        delegate: Item {
                                            required property var modelData

                                            width: parent.width
                                            height: 20

                                            Text {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 116
                                                text: modelData.label
                                                color: root.palette.mutedText
                                                font.pixelSize: 13
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                anchors.left: parent.left
                                                anchors.leftMargin: 126
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelData.value
                                                color: root.palette.primaryText
                                                font.pixelSize: 14
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width - 320 - 360 - 28
                        height: parent.height
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.panelBorder

                        Column {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10

                            Column {
                                visible: root.rightPaneMode === "dataset"
                                width: parent.width
                                height: visible ? parent.height : 0
                                spacing: 10

                                Rectangle {
                                    width: parent.width
                                    height: 196
                                    radius: 8
                                    color: root.palette.panelBackground
                                    border.width: 1
                                    border.color: root.palette.frameBorder

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 8

                                        Text {
                                            text: "Dataset Management"
                                            color: root.palette.accent
                                            font.pixelSize: 15
                                            font.bold: true
                                        }

                                        Text {
                                            width: parent.width
                                            text: root.selectedDatasetName || "No dataset selected"
                                            color: root.palette.primaryText
                                            font.pixelSize: 17
                                            minimumPixelSize: 12
                                            fontSizeMode: Text.HorizontalFit
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: parent.width
                                            text: root.selectedDatasetDetail()
                                            color: root.palette.mutedText
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                        }

                                        Rectangle {
                                            width: parent.width
                                            height: 40
                                            radius: 8
                                            color: datasetManageCreateMouse.containsMouse ? root.palette.cardHover : Qt.alpha(root.palette.success, 0.12)
                                            border.width: 1
                                            border.color: root.palette.success
                                            opacity: root.selectedDatasetCanHaveChildren() && !root.runningAction ? 1 : 0.45

                                            Text {
                                                anchors.centerIn: parent
                                                text: "New Dataset"
                                                color: root.palette.success
                                                font.pixelSize: 13
                                                font.bold: true
                                            }

                                            MouseArea {
                                                id: datasetManageCreateMouse

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: root.selectedDatasetCanHaveChildren() ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                enabled: root.selectedDatasetCanHaveChildren() && !root.runningAction
                                                onClicked: root.openCreateDatasetDialog()
                                            }
                                        }

                                        Rectangle {
                                            width: parent.width
                                            height: 40
                                            radius: 8
                                            color: datasetManageSnapshotsMouse.containsMouse ? root.palette.cardHover : root.palette.cardBackground
                                            border.width: 1
                                            border.color: root.palette.accent
                                            opacity: root.selectedDatasetName && !root.runningAction ? 1 : 0.45

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Snapshots"
                                                color: root.palette.accent
                                                font.pixelSize: 13
                                                font.bold: true
                                            }

                                            MouseArea {
                                                id: datasetManageSnapshotsMouse

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: root.selectedDatasetName ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                enabled: root.selectedDatasetName && !root.runningAction
                                                onClicked: root.showSnapshots()
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: parent.height - 196 - 10
                                    radius: 8
                                    color: root.palette.panelBackground
                                    border.width: 1
                                    border.color: root.palette.frameBorder

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 4

                                        Text {
                                            text: "Selected Dataset"
                                            color: root.palette.accent
                                            font.pixelSize: 14
                                            font.bold: true
                                        }

                                        Repeater {
                                            model: root.selectedDataset ? [
                                                {"label": "Type", "value": root.selectedDataset.type},
                                                {"label": "Mountpoint", "value": root.propertyValue(root.selectedDataset.mountpoint)},
                                                {"label": "Encryption", "value": root.propertyValue(root.selectedDataset.encryption)},
                                                {"label": "Snapshots", "value": root.selectedDatasetSnapshotCount().toString()}
                                            ] : [
                                                {"label": "Dataset", "value": "None selected"}
                                            ]

                                            delegate: Item {
                                                required property var modelData

                                                width: parent.width
                                                height: 18

                                                Text {
                                                    anchors.left: parent.left
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 78
                                                    text: modelData.label
                                                    color: root.palette.mutedText
                                                    font.pixelSize: 11
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 86
                                                    anchors.right: parent.right
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: modelData.value
                                                    color: root.palette.primaryText
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                visible: root.rightPaneMode === "snapshots"
                                width: parent.width
                                height: visible ? 274 : 0
                                radius: 8
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.frameBorder

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8

                                    Text {
                                        text: "Create Snapshot"
                                        color: root.palette.accent
                                        font.pixelSize: 15
                                        font.bold: true
                                    }

                                    Text {
                                        width: parent.width
                                        text: root.selectedDatasetName || "No dataset selected"
                                        color: root.palette.primaryText
                                        font.pixelSize: 17
                                        minimumPixelSize: 12
                                        fontSizeMode: Text.HorizontalFit
                                        font.bold: true
                                    }

                                    Text {
                                        width: parent.width
                                        text: root.selectedDatasetDetail()
                                        color: root.palette.mutedText
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: 42
                                        radius: 8
                                        color: root.palette.cardBackground
                                        border.width: 1
                                        border.color: snapshotInput.activeFocus ? root.palette.accent : root.palette.frameBorder

                                        MouseArea {
                                            anchors.fill: parent
                                            acceptedButtons: Qt.LeftButton
                                            onClicked: snapshotInput.forceActiveFocus()
                                        }

                                        TextInput {
                                            id: snapshotInput

                                            anchors.fill: parent
                                            anchors.margins: 10
                                            text: root.snapshotName
                                            color: root.palette.primaryText
                                            selectionColor: root.palette.accent
                                            selectedTextColor: root.palette.frameBackground
                                            font.pixelSize: 14
                                            clip: true
                                            onTextChanged: root.snapshotName = text

                                            Text {
                                                anchors.fill: parent
                                                visible: snapshotInput.text.length === 0 && !snapshotInput.activeFocus
                                                text: "snapshot label (optional)"
                                                color: root.palette.mutedText
                                                font.pixelSize: 14
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }
                                    }

                                    Row {
                                        width: parent.width
                                        spacing: 6

                                        Repeater {
                                            model: root.snapshotPresets

                                            Rectangle {
                                                id: presetChip

                                                required property string modelData

                                                width: Math.floor((parent.width - 12) / 3)
                                                height: 28
                                                radius: 7
                                                color: presetMouse.containsMouse ? root.palette.cardHover : root.palette.cardBackground
                                                border.width: 1
                                                border.color: root.snapshotName === modelData ? root.palette.accent : root.palette.frameBorder

                                                Text {
                                                    anchors.centerIn: parent
                                                    width: parent.width - 10
                                                    text: presetChip.modelData
                                                    color: root.snapshotName === presetChip.modelData ? root.palette.accent : root.palette.secondaryText
                                                    font.pixelSize: 11
                                                    font.bold: root.snapshotName === presetChip.modelData
                                                    horizontalAlignment: Text.AlignHCenter
                                                    elide: Text.ElideRight
                                                }

                                                MouseArea {
                                                    id: presetMouse

                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        root.snapshotName = presetChip.modelData
                                                        snapshotInput.forceActiveFocus()
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: 40
                                        radius: 8
                                        color: createMouse.containsMouse ? root.palette.cardHover : Qt.alpha(root.palette.success, 0.12)
                                        border.width: 1
                                        border.color: root.palette.success
                                        opacity: root.selectedDatasetName && !root.runningAction ? 1 : 0.45

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Create Snapshot"
                                            color: root.palette.success
                                            font.pixelSize: 14
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: createMouse

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: root.selectedDatasetName && !root.runningAction
                                            onClicked: root.requestAction(
                                                "create-snapshot",
                                                "Creating snapshot",
                                                "Create a snapshot of " + root.selectedDatasetName + " named " + root.createSnapshotLabel() + "?"
                                            )
                                        }
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: 40
                                        radius: 8
                                        color: snapshotDatasetsMouse.containsMouse ? root.palette.cardHover : root.palette.cardBackground
                                        border.width: 1
                                        border.color: root.palette.accent
                                        opacity: root.selectedDatasetName && !root.runningAction ? 1 : 0.45

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Datasets"
                                            color: root.palette.accent
                                            font.pixelSize: 13
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: snapshotDatasetsMouse

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: root.selectedDatasetName ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            enabled: root.selectedDatasetName && !root.runningAction
                                            onClicked: root.showDatasetDetails()
                                        }
                                    }
                                }
                            }

                            Item {
                                visible: root.rightPaneMode === "snapshots"
                                width: parent.width
                                height: visible ? 6 : 0

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 2
                                    color: Qt.alpha(root.palette.accent, 0.72)
                                }
                            }

                            Item {
                                visible: false
                                width: parent.width
                                height: 0
                            }

                            Rectangle {
                                visible: root.rightPaneMode === "snapshots"
                                width: parent.width
                                height: visible ? 174 : 0
                                radius: 8
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.frameBorder

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8

                                    Text {
                                        text: root.centerPaneMode === "snapshots" ? "Current Selection" : "Snapshot Summary"
                                        color: root.palette.accent
                                        font.pixelSize: 15
                                        font.bold: true
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: 74
                                        radius: 8
                                        color: snapshotSummaryMouse.containsMouse && root.centerPaneMode !== "snapshots" ? root.palette.cardHover : root.palette.cardBackground
                                        border.width: 1
                                        border.color: root.centerPaneMode !== "snapshots" ? root.palette.accent : root.palette.frameBorder

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 4

                                            Text {
                                                width: parent.width
                                                text: root.centerPaneMode === "snapshots" ? (root.selectedSnapshot ? root.selectedSnapshot.name : "No snapshot selected") : (root.selectedDatasetName || "No dataset selected")
                                                color: root.palette.primaryText
                                                font.pixelSize: 15
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                width: parent.width
                                                text: root.centerPaneMode === "snapshots" ? root.selectedSnapshotDetail() : root.selectedDatasetSnapshotCount() + " recent snapshot(s). Click to browse."
                                                color: root.palette.mutedText
                                                font.pixelSize: 11
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 2
                                                elide: Text.ElideRight
                                            }
                                        }

                                        MouseArea {
                                            id: snapshotSummaryMouse

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: root.centerPaneMode !== "snapshots" && root.selectedDatasetName ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            enabled: root.centerPaneMode !== "snapshots" && root.selectedDatasetName
                                            onClicked: root.showSnapshots()
                                        }
                                    }

                                    Rectangle {
                                        visible: root.centerPaneMode !== "snapshots"
                                        width: parent.width
                                        height: visible ? 36 : 0
                                        radius: 8
                                        color: root.palette.cardBackground
                                        border.width: 1
                                        border.color: root.palette.frameBorder

                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            text: root.latestSnapshot() ? "Latest: " + root.latestSnapshot().snapshot : "Latest: none"
                                            color: root.palette.secondaryText
                                            font.pixelSize: 12
                                            font.bold: true
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Row {
                                        visible: root.centerPaneMode === "snapshots"
                                        height: visible ? 36 : 0
                                        spacing: 8

                                        Repeater {
                                            model: [
                                                {"label": "Rollback", "action": "rollback-snapshot", "tone": "warning"},
                                                {"label": "Destroy", "action": "destroy-snapshot", "tone": "error"}
                                            ]

                                            delegate: Rectangle {
                                                id: actionButton

                                                required property var modelData
                                                readonly property color accent: root.toneColor(modelData.tone)

                                                width: 122
                                                height: 36
                                                radius: 8
                                                color: actionMouse.containsMouse ? root.palette.cardHover : Qt.alpha(accent, 0.10)
                                                border.width: 1
                                                border.color: accent
                                                opacity: root.selectedSnapshotName && !root.runningAction ? 1 : 0.45

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: actionButton.modelData.label
                                                    color: actionButton.accent
                                                    font.pixelSize: 13
                                                    font.bold: true
                                                }

                                                MouseArea {
                                                    id: actionMouse

                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    enabled: root.selectedSnapshotName && !root.runningAction
                                                    onClicked: root.requestAction(
                                                        actionButton.modelData.action,
                                                        actionButton.modelData.label + " snapshot",
                                                        actionButton.modelData.label + " " + root.selectedSnapshotName + "?"
                                                    )
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
                visible: root.datasetDialogOpen
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.55)

                Rectangle {
                    anchors.centerIn: parent
                    width: 760
                    height: 598
                    radius: 8
                    color: root.palette.cardBackground
                    border.width: 1
                    border.color: root.palette.success

                    Column {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 12

                        Text {
                            width: parent.width
                            text: "Create Dataset"
                            color: root.palette.primaryText
                            font.pixelSize: 24
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Row {
                            width: parent.width
                            height: 88
                            spacing: 12

                            Rectangle {
                                width: Math.floor((parent.width - 12) / 2)
                                height: parent.height
                                radius: 8
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.frameBorder

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 6

                                    Text {
                                        text: "Parent"
                                        color: root.palette.mutedText
                                        font.pixelSize: 11
                                        font.bold: true
                                    }

                                    Text {
                                        width: parent.width
                                        text: root.selectedDatasetName || "No dataset selected"
                                        color: root.palette.primaryText
                                        font.pixelSize: 17
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        text: "Nested paths create missing parent datasets."
                                        color: root.palette.mutedText
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            Column {
                                width: Math.floor((parent.width - 12) / 2)
                                height: parent.height
                                spacing: 8

                                Rectangle {
                                    width: parent.width
                                    height: 48
                                    radius: 8
                                    color: root.palette.panelBackground
                                    border.width: 1
                                    border.color: datasetNameInput.activeFocus ? root.palette.accent : root.palette.frameBorder

                                    MouseArea {
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton
                                        onClicked: datasetNameInput.forceActiveFocus()
                                    }

                                    TextInput {
                                        id: datasetNameInput

                                        anchors.fill: parent
                                        anchors.margins: 11
                                        text: root.datasetChildName
                                        color: root.palette.primaryText
                                        selectionColor: root.palette.accent
                                        selectedTextColor: root.palette.frameBackground
                                        font.pixelSize: 14
                                        clip: true
                                        onTextChanged: root.datasetChildName = text
                                        onAccepted: root.requestCreateDataset()

                                        Text {
                                            anchors.fill: parent
                                            visible: datasetNameInput.text.length === 0 && !datasetNameInput.activeFocus
                                            text: "dataset name or path"
                                            color: root.palette.mutedText
                                            font.pixelSize: 14
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }

                                Row {
                                    width: parent.width
                                    height: 30
                                    spacing: 8

                                    Repeater {
                                        model: root.datasetNamePresets

                                        Rectangle {
                                            id: datasetPresetChip

                                            required property string modelData

                                            width: Math.floor((parent.width - 8) / 2)
                                            height: 30
                                            radius: 7
                                            color: datasetPresetMouse.containsMouse ? root.palette.cardHover : root.palette.panelBackground
                                            border.width: 1
                                            border.color: root.datasetChildName === modelData ? root.palette.accent : root.palette.frameBorder

                                            Text {
                                                anchors.centerIn: parent
                                                width: parent.width - 10
                                                text: datasetPresetChip.modelData
                                                color: root.datasetChildName === datasetPresetChip.modelData ? root.palette.accent : root.palette.secondaryText
                                                font.pixelSize: 11
                                                font.bold: root.datasetChildName === datasetPresetChip.modelData
                                                horizontalAlignment: Text.AlignHCenter
                                                elide: Text.ElideRight
                                            }

                                            MouseArea {
                                                id: datasetPresetMouse

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.datasetChildName = datasetPresetChip.modelData
                                                    datasetNameInput.forceActiveFocus()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 292
                            radius: 8
                            color: root.palette.panelBackground
                            border.width: 1
                            border.color: root.palette.frameBorder

                            Column {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10

                                Text {
                                    text: "Dataset Options"
                                    color: root.palette.accent
                                    font.pixelSize: 15
                                    font.bold: true
                                }

                                Row {
                                    width: parent.width
                                    height: 72
                                    spacing: 10

                                    Column {
                                        width: Math.floor((parent.width - 20) / 3)
                                        height: parent.height
                                        spacing: 6

                                        Text {
                                            text: "Mountpoint"
                                            color: root.palette.mutedText
                                            font.pixelSize: 11
                                            font.bold: true
                                        }

                                        Rectangle {
                                            width: parent.width
                                            height: 42
                                            radius: 8
                                            color: root.palette.cardBackground
                                            border.width: 1
                                            border.color: datasetMountpointInput.activeFocus ? root.palette.accent : root.palette.frameBorder

                                            MouseArea {
                                                anchors.fill: parent
                                                acceptedButtons: Qt.LeftButton
                                                onClicked: datasetMountpointInput.forceActiveFocus()
                                            }

                                            TextInput {
                                                id: datasetMountpointInput

                                                anchors.fill: parent
                                                anchors.margins: 10
                                                text: root.datasetMountpoint
                                                color: root.palette.primaryText
                                                selectionColor: root.palette.accent
                                                selectedTextColor: root.palette.frameBackground
                                                font.pixelSize: 13
                                                clip: true
                                                onTextChanged: root.datasetMountpoint = text

                                                Text {
                                                    anchors.fill: parent
                                                    visible: datasetMountpointInput.text.length === 0 && !datasetMountpointInput.activeFocus
                                                    text: "inherit, /path, none"
                                                    color: root.palette.mutedText
                                                    font.pixelSize: 13
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                            }
                                        }
                                    }

                                    Column {
                                        width: Math.floor((parent.width - 20) / 3)
                                        height: parent.height
                                        spacing: 6

                                        Text {
                                            text: "Quota"
                                            color: root.palette.mutedText
                                            font.pixelSize: 11
                                            font.bold: true
                                        }

                                        Rectangle {
                                            width: parent.width
                                            height: 42
                                            radius: 8
                                            color: root.palette.cardBackground
                                            border.width: 1
                                            border.color: datasetQuotaInput.activeFocus ? root.palette.accent : root.palette.frameBorder

                                            MouseArea {
                                                anchors.fill: parent
                                                acceptedButtons: Qt.LeftButton
                                                onClicked: datasetQuotaInput.forceActiveFocus()
                                            }

                                            TextInput {
                                                id: datasetQuotaInput

                                                anchors.fill: parent
                                                anchors.margins: 10
                                                text: root.datasetQuota
                                                color: root.palette.primaryText
                                                selectionColor: root.palette.accent
                                                selectedTextColor: root.palette.frameBackground
                                                font.pixelSize: 13
                                                clip: true
                                                onTextChanged: root.datasetQuota = text

                                                Text {
                                                    anchors.fill: parent
                                                    visible: datasetQuotaInput.text.length === 0 && !datasetQuotaInput.activeFocus
                                                    text: "inherit, none, 10G"
                                                    color: root.palette.mutedText
                                                    font.pixelSize: 13
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                            }
                                        }
                                    }

                                    Column {
                                        width: Math.floor((parent.width - 20) / 3)
                                        height: parent.height
                                        spacing: 6

                                        Text {
                                            text: "Reservation"
                                            color: root.palette.mutedText
                                            font.pixelSize: 11
                                            font.bold: true
                                        }

                                        Rectangle {
                                            width: parent.width
                                            height: 42
                                            radius: 8
                                            color: root.palette.cardBackground
                                            border.width: 1
                                            border.color: datasetReservationInput.activeFocus ? root.palette.accent : root.palette.frameBorder

                                            MouseArea {
                                                anchors.fill: parent
                                                acceptedButtons: Qt.LeftButton
                                                onClicked: datasetReservationInput.forceActiveFocus()
                                            }

                                            TextInput {
                                                id: datasetReservationInput

                                                anchors.fill: parent
                                                anchors.margins: 10
                                                text: root.datasetReservation
                                                color: root.palette.primaryText
                                                selectionColor: root.palette.accent
                                                selectedTextColor: root.palette.frameBackground
                                                font.pixelSize: 13
                                                clip: true
                                                onTextChanged: root.datasetReservation = text

                                                Text {
                                                    anchors.fill: parent
                                                    visible: datasetReservationInput.text.length === 0 && !datasetReservationInput.activeFocus
                                                    text: "inherit, none, 5G"
                                                    color: root.palette.mutedText
                                                    font.pixelSize: 13
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                            }
                                        }
                                    }
                                }

                                Row {
                                    width: parent.width
                                    height: 168
                                    spacing: 10

                                    Column {
                                        width: Math.floor((parent.width - 20) / 3)
                                        height: parent.height
                                        spacing: 8

                                        Text {
                                            text: "Compression"
                                            color: root.palette.mutedText
                                            font.pixelSize: 11
                                            font.bold: true
                                        }

                                        Column {
                                            width: parent.width
                                            spacing: 6

                                            Repeater {
                                                model: root.datasetCompressionOptions

                                                Rectangle {
                                                    id: compressionChip

                                                    required property string modelData

                                                    width: parent.width
                                                    height: 28
                                                    radius: 7
                                                    color: compressionMouse.containsMouse ? root.palette.cardHover : root.palette.cardBackground
                                                    border.width: 1
                                                    border.color: root.datasetCompression === modelData ? root.palette.accent : root.palette.frameBorder

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: compressionChip.modelData
                                                        color: root.datasetCompression === compressionChip.modelData ? root.palette.accent : root.palette.secondaryText
                                                        font.pixelSize: 11
                                                        font.bold: root.datasetCompression === compressionChip.modelData
                                                    }

                                                    MouseArea {
                                                        id: compressionMouse

                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.datasetCompression = compressionChip.modelData
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Column {
                                        width: Math.floor((parent.width - 20) / 3)
                                        height: parent.height
                                        spacing: 8

                                        Text {
                                            text: "Atime"
                                            color: root.palette.mutedText
                                            font.pixelSize: 11
                                            font.bold: true
                                        }

                                        Column {
                                            width: parent.width
                                            spacing: 6

                                            Repeater {
                                                model: root.datasetAtimeOptions

                                                Rectangle {
                                                    id: atimeChip

                                                    required property string modelData

                                                    width: parent.width
                                                    height: 28
                                                    radius: 7
                                                    color: atimeMouse.containsMouse ? root.palette.cardHover : root.palette.cardBackground
                                                    border.width: 1
                                                    border.color: root.datasetAtime === modelData ? root.palette.accent : root.palette.frameBorder

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: atimeChip.modelData
                                                        color: root.datasetAtime === atimeChip.modelData ? root.palette.accent : root.palette.secondaryText
                                                        font.pixelSize: 11
                                                        font.bold: root.datasetAtime === atimeChip.modelData
                                                    }

                                                    MouseArea {
                                                        id: atimeMouse

                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.datasetAtime = atimeChip.modelData
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Column {
                                        width: Math.floor((parent.width - 20) / 3)
                                        height: parent.height
                                        spacing: 8

                                        Text {
                                            text: "Recordsize"
                                            color: root.palette.mutedText
                                            font.pixelSize: 11
                                            font.bold: true
                                        }

                                        Grid {
                                            width: parent.width
                                            columns: 2
                                            spacing: 6

                                            Repeater {
                                                model: root.datasetRecordsizeOptions

                                                Rectangle {
                                                    id: recordsizeChip

                                                    required property string modelData

                                                    width: Math.floor((parent.width - 6) / 2)
                                                    height: 28
                                                    radius: 7
                                                    color: recordsizeMouse.containsMouse ? root.palette.cardHover : root.palette.cardBackground
                                                    border.width: 1
                                                    border.color: root.datasetRecordsize === modelData ? root.palette.accent : root.palette.frameBorder

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: recordsizeChip.modelData
                                                        color: root.datasetRecordsize === recordsizeChip.modelData ? root.palette.accent : root.palette.secondaryText
                                                        font.pixelSize: 11
                                                        font.bold: root.datasetRecordsize === recordsizeChip.modelData
                                                    }

                                                    MouseArea {
                                                        id: recordsizeMouse

                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.datasetRecordsize = recordsizeChip.modelData
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 42
                            radius: 8
                            color: root.palette.panelBackground
                            border.width: 1
                            border.color: root.datasetFullName().length > 0 ? root.palette.success : root.palette.frameBorder

                            Text {
                                anchors.fill: parent
                                anchors.margins: 9
                                text: root.datasetFullName().length > 0 ? root.datasetFullName() : "Select a parent and name"
                                color: root.datasetFullName().length > 0 ? root.palette.success : root.palette.mutedText
                                font.pixelSize: 13
                                font.bold: root.datasetFullName().length > 0
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: 10

                            Rectangle {
                                width: Math.floor((parent.width - 10) / 2)
                                height: 42
                                radius: 8
                                color: datasetCreateMouse.containsMouse ? root.palette.cardHover : Qt.alpha(root.palette.success, 0.12)
                                border.width: 1
                                border.color: root.palette.success
                                opacity: root.datasetChildName.length > 0 && root.selectedDatasetCanHaveChildren() && !root.runningAction ? 1 : 0.45

                                Text {
                                    anchors.centerIn: parent
                                    text: "Create Dataset"
                                    color: root.palette.success
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                MouseArea {
                                    id: datasetCreateMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: root.datasetChildName.length > 0 && root.selectedDatasetCanHaveChildren() && !root.runningAction
                                    onClicked: root.requestCreateDataset()
                                }
                            }

                            Rectangle {
                                width: Math.floor((parent.width - 10) / 2)
                                height: 42
                                radius: 8
                                color: datasetCancelMouse.containsMouse ? root.palette.cardHover : root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.panelBorder

                                Text {
                                    anchors.centerIn: parent
                                    text: "Cancel"
                                    color: root.palette.secondaryText
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                MouseArea {
                                    id: datasetCancelMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.datasetDialogOpen = false
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: root.pendingActionId.length > 0
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.55)

                Rectangle {
                    anchors.centerIn: parent
                    width: 360
                    height: root.pendingActionId === "create-snapshot" ? 214 : 190
                    radius: 8
                    color: root.palette.cardBackground
                    border.width: 1
                    border.color: root.palette.warning

                    Column {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 12

                        Text {
                            text: root.pendingActionLabel
                            color: root.palette.primaryText
                            font.pixelSize: 22
                            font.bold: true
                        }

                        Text {
                            width: parent.width
                            text: root.pendingActionDescription
                            color: root.palette.secondaryText
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                        }

                        Row {
                            spacing: 10

                            Rectangle {
                                width: 150
                                height: 42
                                radius: 8
                                color: confirmMouse.containsMouse ? root.palette.cardHover : Qt.alpha(root.palette.warning, 0.12)
                                border.width: 1
                                border.color: root.palette.warning

                                Text {
                                    anchors.centerIn: parent
                                    text: "Confirm"
                                    color: root.palette.warning
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
                                width: 150
                                height: 42
                                radius: 8
                                color: cancelMouse.containsMouse ? root.palette.cardHover : root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.panelBorder

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

                        Rectangle {
                            visible: root.pendingActionId === "create-snapshot"
                            width: 310
                            height: visible ? 34 : 0
                            radius: 8
                            color: recursiveMouse.containsMouse ? root.palette.cardHover : root.palette.panelBackground
                            border.width: 1
                            border.color: root.pendingSnapshotRecursive ? root.palette.accent : root.palette.frameBorder

                            Row {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8

                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: 4
                                    color: root.pendingSnapshotRecursive ? root.palette.accent : root.palette.cardBackground
                                    border.width: 1
                                    border.color: root.pendingSnapshotRecursive ? root.palette.accentStrong : root.palette.frameBorder

                                    Text {
                                        anchors.centerIn: parent
                                        visible: root.pendingSnapshotRecursive
                                        text: "X"
                                        color: root.palette.frameBackground
                                        font.pixelSize: 12
                                        font.bold: true
                                    }
                                }

                                Text {
                                    width: parent.width - 26
                                    height: parent.height
                                    text: "Recursive snapshot"
                                    color: root.pendingSnapshotRecursive ? root.palette.primaryText : root.palette.secondaryText
                                    font.pixelSize: 12
                                    font.bold: root.pendingSnapshotRecursive
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: recursiveMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.pendingSnapshotRecursive = !root.pendingSnapshotRecursive
                            }
                        }
                    }
                }
            }
        }
    }
}
