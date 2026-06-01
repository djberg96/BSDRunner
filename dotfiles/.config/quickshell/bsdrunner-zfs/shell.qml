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
    property bool loading: false
    property bool runningAction: false
    property string statusTone: "info"
    property string statusMessage: "Loading ZFS status..."
    property string actionDetails: ""
    property string activeActionId: ""
    property string activeActionArg1: ""
    property string activeActionArg2: ""
    property string activeActionLabel: ""
    property string activeActionArg3: ""
    property string pendingActionId: ""
    property string pendingActionLabel: ""
    property string pendingActionDescription: ""
    property bool pendingSnapshotRecursive: false
    property string snapshotName: ""
    property string selectedDatasetName: ""
    property string selectedSnapshotName: ""
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
            return "Select a dataset to create or browse snapshots."
        return selectedDataset.used + " used / " + selectedDataset.avail + " free"
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
        activeActionArg1 = pendingActionId === "create-snapshot" ? selectedDatasetName : selectedSnapshotName
        activeActionArg2 = pendingActionId === "create-snapshot" ? snapshotName : ""
        activeActionArg3 = pendingActionId === "create-snapshot" && pendingSnapshotRecursive ? "recursive" : ""
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

        if ((!selectedDatasetName || !findByName(datasets, selectedDatasetName)) && datasets.length > 0)
            selectedDatasetName = datasets[0].name

        var filtered = snapshotsForDataset(selectedDatasetName)
        if (filtered.length > 0 && (!selectedSnapshotName || !findByName(filtered, selectedSnapshotName)))
            selectedSnapshotName = filtered[filtered.length - 1].name
        else if (filtered.length === 0)
            selectedSnapshotName = ""
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
            statusTone = activeActionId === "create-snapshot" ? "success" : "warning"
            statusMessage = payload.message || "ZFS action completed."
            actionDetails = payload.details || ""
            snapshotName = ""
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

        command: ["sh", themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-zfs-backend.sh", root.activeActionId, root.activeActionArg1, root.activeActionArg2, root.activeActionArg3]
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
                        width: 300
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
                        width: 330
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
                                model: root.pools.length > 0 ? root.pools.slice(0, 3) : [{"name": "No pool", "size": "--", "free": "--", "health": "--"}]

                                delegate: Rectangle {
                                    required property var modelData

                                    width: 94
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
                        }
                    }

                    Rectangle {
                        width: parent.width - 300 - 330 - 28
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
                                width: parent.width
                                height: parent.height - 30
                                clip: true
                                model: root.datasets
                                spacing: 6

                                delegate: Rectangle {
                                    id: datasetRow

                                    required property var modelData
                                    readonly property bool selected: root.selectedDatasetName === modelData.name

                                    width: ListView.view.width
                                    height: 52
                                    radius: 8
                                    color: selected ? Qt.alpha(root.palette.accent, 0.16) : root.palette.panelBackground
                                    border.width: 1
                                    border.color: selected ? root.palette.accent : root.palette.frameBorder

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 8
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
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.selectedDatasetName = modelData.name
                                            if (root.visibleSnapshots.length > 0)
                                                root.selectedSnapshotName = root.visibleSnapshots[root.visibleSnapshots.length - 1].name
                                            else
                                                root.selectedSnapshotName = ""
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
                                text: "Snapshots"
                                color: root.palette.accent
                                font.pixelSize: 15
                                font.bold: true
                            }

                            ListView {
                                width: parent.width
                                height: parent.height - 30
                                clip: true
                                model: root.visibleSnapshots
                                spacing: 8

                                delegate: Rectangle {
                                    id: snapshotRow

                                    required property var modelData
                                    readonly property bool selected: root.selectedSnapshotName === modelData.name

                                    width: ListView.view.width
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
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selectedSnapshotName = modelData.name
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

                            Rectangle {
                                width: parent.width
                                height: 226
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
                                }
                            }

                            Item {
                                width: parent.width
                                height: 14

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 2
                                    color: Qt.alpha(root.palette.accent, 0.72)
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 164
                                radius: 8
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.frameBorder

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8

                                    Text {
                                        text: "Current Selection"
                                        color: root.palette.accent
                                        font.pixelSize: 15
                                        font.bold: true
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: 74
                                        radius: 8
                                        color: root.palette.cardBackground
                                        border.width: 1
                                        border.color: root.palette.frameBorder

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 4

                                            Text {
                                                width: parent.width
                                                text: root.selectedSnapshot ? root.selectedSnapshot.name : "No snapshot selected"
                                                color: root.palette.primaryText
                                                font.pixelSize: 15
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                width: parent.width
                                                text: root.selectedSnapshotDetail()
                                                color: root.palette.mutedText
                                                font.pixelSize: 11
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 2
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    Row {
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
                                                    text: modelData.label
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
                                                        modelData.action,
                                                        modelData.label + " snapshot",
                                                        modelData.label + " " + root.selectedSnapshotName + "?"
                                                    )
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 40
                                radius: 8
                                color: refreshMouse.containsMouse ? root.palette.cardHover : root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.panelBorder

                                Text {
                                    anchors.centerIn: parent
                                    text: root.loading ? "Refreshing..." : "Refresh"
                                    color: root.palette.secondaryText
                                    font.pixelSize: 13
                                    font.bold: true
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
