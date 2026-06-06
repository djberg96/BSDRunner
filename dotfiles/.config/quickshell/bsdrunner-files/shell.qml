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
    readonly property string homeDir: themeLoader.homeDir
    readonly property string backendScript: homeDir + "/.config/bsdrunner/scripts/bsdrunner-files-backend.sh"
    property string currentPath: homeDir
    property string parentPath: homeDir
    property string pathInputText: homeDir
    property string filterText: ""
    property string statusMessage: "Loading files..."
    property string statusTone: "info"
    property bool loading: false
    property bool showHidden: false
    property var entries: []
    property var shortcuts: []
    property var recentPaths: []
    property string selectedPath: ""
    property var history: []
    property int historyIndex: -1
    property string queuedPath: ""
    property bool queuedHistory: true
    property string snapshotStdoutText: ""
    property string snapshotStderrText: ""
    property int snapshotExitCode: 0
    property bool snapshotExited: false
    property bool snapshotStdoutFinished: false
    property bool snapshotStderrFinished: false
    property string pendingOpenPath: ""
    property string openStdoutText: ""
    property string openStderrText: ""
    property int openExitCode: 0
    property bool openExited: false
    property bool openStdoutFinished: false
    property bool openStderrFinished: false
    property bool actionDialogOpen: false
    property string actionDialogMode: ""
    property string actionDialogTitle: ""
    property string actionDialogMessage: ""
    property string actionDialogValue: ""
    property string actionDialogTargetPath: ""
    property string actionDialogTargetName: ""
    property string pendingActionId: ""
    property string pendingActionArg1: ""
    property string pendingActionArg2: ""
    property string actionStdoutText: ""
    property string actionStderrText: ""
    property int actionExitCode: 0
    property bool actionExited: false
    property bool actionStdoutFinished: false
    property bool actionStderrFinished: false
    property bool runningAction: false
    property bool contextMenuOpen: false
    property real contextMenuX: 0
    property real contextMenuY: 0
    property string contextMenuKind: ""
    property string contextMenuTargetPath: ""
    property string contextMenuTargetName: ""
    property string contextMenuTargetKind: ""
    readonly property var visibleEntries: filteredEntries()
    readonly property var breadcrumbs: breadcrumbEntries()
    readonly property var recentShortcuts: recentEntries()
    readonly property var contextMenuActions: buildContextMenuActions()

    function cleanPath(value) {
        var text = String(value || "").trim()
        if (text.length === 0)
            return currentPath
        if (text === "~")
            return homeDir
        if (text.indexOf("~/") === 0)
            return homeDir + text.slice(1)
        if (text.charAt(0) === "/")
            return text
        if (currentPath === "/")
            return "/" + text
        return currentPath + "/" + text
    }

    function filteredEntries() {
        var query = filterText.trim().toLowerCase()
        var result = []

        for (var i = 0; i < entries.length; i += 1) {
            var entry = entries[i]
            if (!showHidden && entry.hidden)
                continue
            if (query.length > 0 && String(entry.name || "").toLowerCase().indexOf(query) === -1)
                continue
            result.push(entry)
        }

        return result
    }

    function entryByPath(path) {
        for (var i = 0; i < visibleEntries.length; i += 1) {
            if (visibleEntries[i].path === path)
                return visibleEntries[i]
        }

        return null
    }

    function kindIcon(kind) {
        switch (kind) {
        case "directory":
            return "DIR"
        case "symlink":
            return "LNK"
        case "other":
            return "OBJ"
        default:
            return "FILE"
        }
    }

    function metaText(entry) {
        var parts = []
        if (entry.kind === "directory")
            parts.push("Folder")
        else
            parts.push(entry.size_label || "")
        if (entry.mtime_label && entry.mtime_label.length > 0)
            parts.push(entry.mtime_label)
        return parts.join("  ")
    }

    function baseName(path) {
        var text = String(path || "")
        if (text === "/")
            return "/"
        var pieces = text.split("/")
        for (var i = pieces.length - 1; i >= 0; i -= 1) {
            if (pieces[i].length > 0)
                return pieces[i]
        }
        return text
    }

    function displayPath(path) {
        if (path === homeDir)
            return "Home"
        if (path.indexOf(homeDir + "/") === 0)
            return "~/" + path.slice(homeDir.length + 1)
        return path
    }

    function rememberPath(path) {
        if (!path || path.length === 0)
            return

        var next = [path]
        for (var i = 0; i < recentPaths.length && next.length < 8; i += 1) {
            if (recentPaths[i] !== path)
                next.push(recentPaths[i])
        }
        recentPaths = next
    }

    function recentEntries() {
        var result = []
        for (var i = 0; i < recentPaths.length; i += 1) {
            var path = recentPaths[i]
            if (path === currentPath)
                continue
            result.push({
                "label": displayPath(path),
                "path": path
            })
            if (result.length >= 5)
                break
        }
        return result
    }

    function breadcrumbEntries() {
        var path = currentPath || "/"
        var result = []

        if (path === "/")
            return [{"label": "/", "path": "/"}]

        if (path === homeDir || path.indexOf(homeDir + "/") === 0) {
            result.push({"label": "Home", "path": homeDir})
            var relative = path === homeDir ? "" : path.slice(homeDir.length + 1)
            var relativeParts = relative.length > 0 ? relative.split("/") : []
            var homeWalk = homeDir
            for (var h = 0; h < relativeParts.length; h += 1) {
                if (relativeParts[h].length === 0)
                    continue
                homeWalk += "/" + relativeParts[h]
                result.push({"label": relativeParts[h], "path": homeWalk})
            }
            return result
        }

        result.push({"label": "/", "path": "/"})
        var parts = path.split("/")
        var walk = ""
        for (var i = 0; i < parts.length; i += 1) {
            if (parts[i].length === 0)
                continue
            walk += "/" + parts[i]
            result.push({"label": parts[i], "path": walk})
        }
        return result
    }

    function pushHistory(path) {
        var next = []
        for (var i = 0; i <= historyIndex && i < history.length; i += 1)
            next.push(history[i])
        if (next.length === 0 || next[next.length - 1] !== path)
            next.push(path)
        history = next
        historyIndex = history.length - 1
    }

    function requestSnapshot(path, recordHistory) {
        var nextPath = cleanPath(path)
        if (snapshotProcess.running) {
            queuedPath = nextPath
            queuedHistory = recordHistory
            return
        }

        currentPath = nextPath
        pathInputText = nextPath
        selectedPath = ""
        loading = true
        statusTone = "info"
        statusMessage = "Loading " + nextPath
        snapshotStdoutText = ""
        snapshotStderrText = ""
        snapshotExitCode = 0
        snapshotExited = false
        snapshotStdoutFinished = false
        snapshotStderrFinished = false
        if (recordHistory)
            pushHistory(nextPath)
        snapshotProcess.running = true
    }

    function navigate(path) {
        requestSnapshot(path, true)
    }

    function refreshCurrent() {
        requestSnapshot(currentPath, false)
    }

    function goHome() {
        navigate(homeDir)
    }

    function goUp() {
        navigate(parentPath || "/")
    }

    function goBack() {
        if (historyIndex <= 0)
            return
        historyIndex -= 1
        requestSnapshot(history[historyIndex], false)
    }

    function goForward() {
        if (historyIndex >= history.length - 1)
            return
        historyIndex += 1
        requestSnapshot(history[historyIndex], false)
    }

    function activate(entry) {
        if (!entry)
            return
        selectedPath = entry.path
        if (entry.kind === "directory") {
            navigate(entry.path)
            return
        }
        openFile(entry.path)
    }

    function activateSelected() {
        if (selectedPath.length === 0 && visibleEntries.length > 0)
            selectedPath = visibleEntries[0].path
        activate(entryByPath(selectedPath))
    }

    function focusList() {
        entryList.forceActiveFocus()
    }

    function focusPathInput() {
        pathInput.forceActiveFocus()
        pathInput.selectAll()
    }

    function focusFilter() {
        filterInput.forceActiveFocus()
        filterInput.selectAll()
    }

    function clearFilter() {
        filterText = ""
        focusList()
    }

    function selectedEntry() {
        if (selectedPath.length === 0)
            return null
        return entryByPath(selectedPath)
    }

    function selectedKindLabel() {
        var entry = selectedEntry()
        if (!entry)
            return "No Selection"
        switch (entry.kind) {
        case "directory":
            return "Folder"
        case "symlink":
            return "Link"
        case "other":
            return "Object"
        default:
            return "File"
        }
    }

    function selectedSizeLabel() {
        var entry = selectedEntry()
        if (!entry)
            return "--"
        return entry.kind === "directory" ? "--" : (entry.size_label || "--")
    }

    function selectedPermissionLabel() {
        var entry = selectedEntry()
        if (!entry)
            return "--"

        var parts = []
        if (entry.readable)
            parts.push("Read")
        if (entry.writable)
            parts.push("Write")
        if (entry.executable)
            parts.push("Execute")
        return parts.length > 0 ? parts.join(" / ") : "No access"
    }

    function detailsValue(key) {
        var entry = selectedEntry()
        if (!entry)
            return "--"

        switch (key) {
        case "type":
            return selectedKindLabel()
        case "size":
            return selectedSizeLabel()
        case "modified":
            return entry.mtime_label || "--"
        case "permissions":
            return selectedPermissionLabel()
        case "hidden":
            return entry.hidden ? "Yes" : "No"
        default:
            return "--"
        }
    }

    function detailsRows() {
        var entry = selectedEntry()
        var rows = [
            {"label": "Type", "key": "type"}
        ]

        if (!entry || entry.kind !== "directory")
            rows.push({"label": "Size", "key": "size"})

        rows.push({"label": "Modified", "key": "modified"})
        rows.push({"label": "Access", "key": "permissions"})
        rows.push({"label": "Hidden", "key": "hidden"})
        return rows
    }

    function actionButtonEnabled(action) {
        if (runningAction || loading)
            return false
        if (action === "rename" || action === "trash")
            return selectedEntry() !== null
        return true
    }

    function openActionDialog(mode) {
        if (contextMenuOpen)
            closeContextMenu()
        if (!actionButtonEnabled(mode))
            return

        var entry = selectedEntry()
        actionDialogMode = mode
        actionDialogValue = ""
        actionDialogTargetPath = entry ? entry.path : ""
        actionDialogTargetName = entry ? entry.name : ""

        switch (mode) {
        case "mkdir":
            actionDialogTitle = "New Folder"
            actionDialogMessage = "Create a folder in " + displayPath(currentPath)
            actionDialogValue = "New Folder"
            break
        case "rename":
            actionDialogTitle = "Rename"
            actionDialogMessage = "Rename " + actionDialogTargetName
            actionDialogValue = actionDialogTargetName
            break
        case "trash":
            actionDialogTitle = "Move to Trash"
            actionDialogMessage = "Move " + actionDialogTargetName + " to trash?"
            break
        default:
            return
        }

        actionDialogOpen = true
        actionDialogTimer.restart()
    }

    function closeActionDialog() {
        actionDialogOpen = false
        actionDialogMode = ""
        actionDialogValue = ""
        actionDialogTargetPath = ""
        actionDialogTargetName = ""
        focusList()
    }

    function runDialogAction() {
        if (!actionDialogOpen || runningAction)
            return

        switch (actionDialogMode) {
        case "mkdir":
            runBackendAction("mkdir", currentPath, actionDialogValue)
            break
        case "rename":
            runBackendAction("rename", actionDialogTargetPath, actionDialogValue)
            break
        case "trash":
            runBackendAction("trash", actionDialogTargetPath, "")
            break
        }

        actionDialogOpen = false
    }

    function openTerminalHere() {
        if (runningAction)
            return
        var entry = selectedEntry()
        var path = currentPath
        if (entry && entry.kind === "directory")
            path = entry.path
        runBackendAction("terminal", path, "")
    }

    function copySelectedPath() {
        if (runningAction)
            return
        var entry = selectedEntry()
        if (!entry)
            return
        runBackendAction("copy-path", entry.path, "")
    }

    function buildContextMenuActions() {
        if (!contextMenuOpen)
            return []

        if (contextMenuKind === "background") {
            return [
                {"label": "New Folder", "action": "mkdir", "tone": "normal"},
                {"label": "Open Terminal Here", "action": "terminal-current", "tone": "normal"},
                {"label": "Refresh", "action": "refresh", "tone": "normal"}
            ]
        }

        var actions = [
            {"label": contextMenuTargetKind === "directory" ? "Open Folder" : "Open", "action": "open", "tone": "normal"},
            {"label": "Rename", "action": "rename", "tone": "normal"},
            {"label": "Copy Path", "action": "copy-path", "tone": "normal"}
        ]

        if (contextMenuTargetKind === "directory")
            actions.push({"label": "Open Terminal Here", "action": "terminal-target", "tone": "normal"})

        actions.push({"label": "Move to Trash", "action": "trash", "tone": "danger"})
        return actions
    }

    function openContextMenu(kind, x, y, entry) {
        closeActionDialog()
        contextMenuKind = kind
        contextMenuX = Math.max(8, Math.min(x, window.width - 188))
        contextMenuY = Math.max(8, Math.min(y, window.height - 220))

        if (entry) {
            selectedPath = entry.path
            contextMenuTargetPath = entry.path
            contextMenuTargetName = entry.name
            contextMenuTargetKind = entry.kind
        } else {
            contextMenuTargetPath = currentPath
            contextMenuTargetName = baseName(currentPath)
            contextMenuTargetKind = "directory"
        }

        contextMenuOpen = true
    }

    function closeContextMenu() {
        contextMenuOpen = false
        contextMenuKind = ""
        contextMenuTargetPath = ""
        contextMenuTargetName = ""
        contextMenuTargetKind = ""
    }

    function runContextMenuAction(actionId) {
        var targetPath = contextMenuTargetPath
        var targetEntry = entryByPath(targetPath)
        closeContextMenu()

        switch (actionId) {
        case "open":
            if (targetEntry)
                activate(targetEntry)
            break
        case "rename":
            if (targetEntry) {
                selectedPath = targetEntry.path
                openActionDialog("rename")
            }
            break
        case "trash":
            if (targetEntry) {
                selectedPath = targetEntry.path
                openActionDialog("trash")
            }
            break
        case "copy-path":
            if (targetEntry) {
                selectedPath = targetEntry.path
                copySelectedPath()
            }
            break
        case "terminal-target":
            runBackendAction("terminal", targetPath, "")
            break
        case "terminal-current":
            runBackendAction("terminal", currentPath, "")
            break
        case "mkdir":
            openActionDialog("mkdir")
            break
        case "refresh":
            refreshCurrent()
            break
        }
    }

    function runBackendAction(actionId, arg1, arg2) {
        if (actionProcess.running)
            return

        pendingActionId = actionId
        pendingActionArg1 = arg1 || ""
        pendingActionArg2 = arg2 || ""
        runningAction = true
        statusTone = "info"
        statusMessage = "Running " + actionId + "..."
        actionStdoutText = ""
        actionStderrText = ""
        actionExitCode = 0
        actionExited = false
        actionStdoutFinished = false
        actionStderrFinished = false
        actionProcess.running = true
    }

    function selectOffset(delta) {
        if (visibleEntries.length === 0)
            return

        var index = 0
        for (var i = 0; i < visibleEntries.length; i += 1) {
            if (visibleEntries[i].path === selectedPath) {
                index = i
                break
            }
        }

        index = Math.max(0, Math.min(visibleEntries.length - 1, index + delta))
        selectedPath = visibleEntries[index].path
        entryList.positionViewAtIndex(index, ListView.Contain)
    }

    function openFile(path) {
        if (openProcess.running)
            return
        pendingOpenPath = path
        statusTone = "info"
        statusMessage = "Opening " + path
        openStdoutText = ""
        openStderrText = ""
        openExitCode = 0
        openExited = false
        openStdoutFinished = false
        openStderrFinished = false
        openProcess.running = true
    }

    function maybeFinalizeSnapshot() {
        if (!snapshotExited || !snapshotStdoutFinished || !snapshotStderrFinished)
            return
        applySnapshot(snapshotStdoutText, snapshotExitCode, snapshotStderrText)
    }

    function applySnapshot(text, exitCode, stderrText) {
        var payload = null

        try {
            payload = JSON.parse(text || "{}")
        } catch (error) {
            payload = null
        }

        loading = false
        if (exitCode !== 0 || !payload || !payload.ok) {
            statusTone = "error"
            statusMessage = payload && payload.message
                ? payload.message
                : (stderrText && stderrText.trim().length > 0 ? stderrText.trim() : "Unable to load directory.")
            entries = []
            shortcuts = []
        } else {
            currentPath = payload.path || currentPath
            parentPath = payload.parent || currentPath
            pathInputText = currentPath
            entries = payload.entries || []
            shortcuts = payload.shortcuts || []
            if (historyIndex >= 0 && historyIndex < history.length)
                history[historyIndex] = currentPath
            rememberPath(currentPath)
            statusTone = "info"
            statusMessage = payload.message || "Loaded " + currentPath
        }

        if (queuedPath.length > 0) {
            var nextPath = queuedPath
            var nextHistory = queuedHistory
            queuedPath = ""
            requestSnapshot(nextPath, nextHistory)
        }
    }

    function maybeFinalizeOpen() {
        if (!openExited || !openStdoutFinished || !openStderrFinished)
            return
        applyOpen(openStdoutText, openExitCode, openStderrText)
    }

    function applyOpen(text, exitCode, stderrText) {
        var payload = null

        try {
            payload = JSON.parse(text || "{}")
        } catch (error) {
            payload = null
        }

        if (exitCode === 0 && payload && payload.ok) {
            statusTone = "info"
            statusMessage = payload.message || "Opened file."
        } else {
            statusTone = "error"
            statusMessage = payload && payload.message
                ? payload.message
                : (stderrText && stderrText.trim().length > 0 ? stderrText.trim() : "Unable to open file.")
        }
    }

    function maybeFinalizeAction() {
        if (!actionExited || !actionStdoutFinished || !actionStderrFinished)
            return
        applyAction(actionStdoutText, actionExitCode, actionStderrText)
    }

    function applyAction(text, exitCode, stderrText) {
        var payload = null

        try {
            payload = JSON.parse(text || "{}")
        } catch (error) {
            payload = null
        }

        runningAction = false
        if (exitCode === 0 && payload && payload.ok) {
            statusTone = "success"
            statusMessage = payload.message || "Action completed."
            if (pendingActionId !== "terminal")
                refreshCurrent()
        } else {
            statusTone = "error"
            statusMessage = payload && payload.message
                ? payload.message
                : (stderrText && stderrText.trim().length > 0 ? stderrText.trim() : "Action failed.")
        }

        pendingActionId = ""
        pendingActionArg1 = ""
        pendingActionArg2 = ""
    }

    function statusColor() {
        if (statusTone === "error")
            return palette.danger
        if (statusTone === "success")
            return palette.success
        return palette.mutedText
    }

    function countLabel() {
        var total = visibleEntries.length
        var suffix = total === 1 ? "entry" : "entries"
        return total + " " + suffix
    }

    onVisibleEntriesChanged: {
        if (visibleEntries.length === 0) {
            selectedPath = ""
            return
        }
        if (!entryByPath(selectedPath))
            selectedPath = visibleEntries[0].path
    }

    Component.onCompleted: {
        currentPath = homeDir
        pathInputText = homeDir
        history = [homeDir]
        historyIndex = 0
        requestSnapshot(homeDir, false)
    }

    Timer {
        id: actionDialogTimer

        interval: 20
        repeat: false
        onTriggered: {
            if (root.actionDialogOpen && root.actionDialogMode !== "trash") {
                actionInput.forceActiveFocus()
                actionInput.selectAll()
            } else if (root.actionDialogOpen) {
                confirmButton.forceActiveFocus()
            }
        }
    }

    Process {
        id: snapshotProcess

        property var controller: root

        command: [
            "sh",
            root.backendScript,
            "snapshot",
            root.currentPath
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                snapshotProcess.controller.snapshotStdoutText = this.text
                snapshotProcess.controller.snapshotStdoutFinished = true
                snapshotProcess.controller.maybeFinalizeSnapshot()
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                snapshotProcess.controller.snapshotStderrText = this.text
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
        id: openProcess

        property var controller: root

        command: [
            "sh",
            root.backendScript,
            "open",
            root.pendingOpenPath
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                openProcess.controller.openStdoutText = this.text
                openProcess.controller.openStdoutFinished = true
                openProcess.controller.maybeFinalizeOpen()
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                openProcess.controller.openStderrText = this.text
                openProcess.controller.openStderrFinished = true
                openProcess.controller.maybeFinalizeOpen()
            }
        }

        onExited: function(exitCode, exitStatus) {
            openProcess.controller.openExitCode = exitCode
            openProcess.controller.openExited = true
            openProcess.controller.maybeFinalizeOpen()
        }
    }

    Process {
        id: actionProcess

        property var controller: root

        command: [
            "sh",
            root.backendScript,
            root.pendingActionId,
            root.pendingActionArg1,
            root.pendingActionArg2
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                actionProcess.controller.actionStdoutText = this.text
                actionProcess.controller.actionStdoutFinished = true
                actionProcess.controller.maybeFinalizeAction()
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                actionProcess.controller.actionStderrText = this.text
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
        id: window

        visible: true
        title: "BSDRunner Files"
        minimumSize: Qt.size(980, 620)
        maximumSize: Qt.size(980, 620)
        color: "transparent"

        Rectangle {
            id: contentRoot

            anchors.fill: parent
            color: root.palette.panelBackground

            Row {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14

                Rectangle {
                    id: leftRail

                    width: 184
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
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
                            text: "Files"
                            color: root.palette.primaryText
                            font.pixelSize: 28
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Flickable {
                            width: parent.width
                            height: parent.height - 42
                            clip: true
                            contentHeight: railContent.height
                            boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: railContent

                                width: parent.width
                                spacing: 10

                                Text {
                                    width: parent.width
                                    text: "Places"
                                    color: root.palette.mutedText
                                    font.pixelSize: 10
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Column {
                                    width: parent.width
                                    spacing: 5

                                    Repeater {
                                        model: root.shortcuts

                                        delegate: Rectangle {
                                            id: shortcutRow

                                            required property var modelData

                                            width: parent.width
                                            height: 30
                                            radius: 6
                                            color: shortcutMouse.containsMouse || root.currentPath === modelData.path
                                                ? root.palette.cardHover
                                                : "transparent"
                                            border.width: root.currentPath === modelData.path ? 1 : 0
                                            border.color: root.palette.accent

                                            Text {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 10
                                                text: shortcutRow.modelData.label
                                                color: root.currentPath === shortcutRow.modelData.path
                                                    ? root.palette.accentStrong
                                                    : root.palette.secondaryText
                                                font.pixelSize: 12
                                                font.bold: root.currentPath === shortcutRow.modelData.path
                                                elide: Text.ElideRight
                                            }

                                            MouseArea {
                                                id: shortcutMouse

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.navigate(shortcutRow.modelData.path)
                                            }
                                        }
                                    }
                                }

                                Text {
                                    width: parent.width
                                    visible: root.recentShortcuts.length > 0
                                    text: "Recent"
                                    color: root.palette.mutedText
                                    font.pixelSize: 10
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Column {
                                    width: parent.width
                                    visible: root.recentShortcuts.length > 0
                                    spacing: 5

                                    Repeater {
                                        model: root.recentShortcuts

                                        delegate: Rectangle {
                                            id: recentRow

                                            required property var modelData

                                            width: parent.width
                                            height: 30
                                            radius: 6
                                            color: recentMouse.containsMouse ? root.palette.cardHover : "transparent"
                                            border.width: 0
                                            border.color: root.palette.frameBorder

                                            Text {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 10
                                                text: recentRow.modelData.label
                                                color: root.palette.secondaryText
                                                font.pixelSize: 12
                                                elide: Text.ElideRight
                                            }

                                            MouseArea {
                                                id: recentMouse

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.navigate(recentRow.modelData.path)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Column {
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width - leftRail.width - parent.spacing
                    spacing: 10

                    Row {
                        width: parent.width
                        height: 34
                        spacing: 8

                        Repeater {
                            model: [
                                {
                                    "label": "<",
                                    "enabled": root.historyIndex > 0,
                                    "action": "back"
                                },
                                {
                                    "label": ">",
                                    "enabled": root.historyIndex < root.history.length - 1,
                                    "action": "forward"
                                },
                                {
                                    "label": "^",
                                    "enabled": root.currentPath !== "/",
                                    "action": "up"
                                },
                                {
                                    "label": "Home",
                                    "enabled": root.currentPath !== root.homeDir,
                                    "action": "home"
                                },
                                {
                                    "label": "Refresh",
                                    "enabled": !root.loading,
                                    "action": "refresh"
                                }
                            ]

                            delegate: Rectangle {
                                id: navButton

                                required property var modelData

                                width: modelData.label.length > 1 ? 70 : 34
                                height: parent.height
                                radius: 6
                                color: navMouse.containsMouse && modelData.enabled
                                    ? root.palette.cardHover
                                    : root.palette.cardBackground
                                opacity: modelData.enabled ? 1.0 : 0.45
                                border.width: 1
                                border.color: navMouse.containsMouse && modelData.enabled
                                    ? root.palette.accent
                                    : root.palette.frameBorder

                                Text {
                                    anchors.centerIn: parent
                                    text: navButton.modelData.label
                                    color: root.palette.primaryText
                                    font.pixelSize: navButton.modelData.label.length > 1 ? 11 : 15
                                    font.bold: true
                                }

                                MouseArea {
                                    id: navMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: navButton.modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        if (!navButton.modelData.enabled)
                                            return
                                        switch (navButton.modelData.action) {
                                        case "back":
                                            root.goBack()
                                            break
                                        case "forward":
                                            root.goForward()
                                            break
                                        case "up":
                                            root.goUp()
                                            break
                                        case "home":
                                            root.goHome()
                                            break
                                        case "refresh":
                                            root.refreshCurrent()
                                            break
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: Math.max(220, parent.width - 324)
                            height: parent.height
                            radius: 6
                            color: root.palette.cardBackground
                            border.width: 1
                            border.color: pathInput.activeFocus ? root.palette.accent : root.palette.frameBorder

                            TextInput {
                                id: pathInput

                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                text: root.pathInputText
                                color: root.palette.primaryText
                                selectionColor: Qt.alpha(root.palette.accent, 0.35)
                                selectedTextColor: root.palette.accentStrong
                                font.pixelSize: 13
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                onTextEdited: root.pathInputText = text
                                onAccepted: root.navigate(text)
                                Keys.onPressed: function(event) {
                                    if (event.key === Qt.Key_Escape) {
                                        text = root.currentPath
                                        root.pathInputText = root.currentPath
                                        root.focusList()
                                        event.accepted = true
                                    } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_F) {
                                        root.focusFilter()
                                        event.accepted = true
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: 34
                            height: parent.height
                            radius: 6
                            color: closeMouse.containsMouse ? root.palette.cardHover : root.palette.cardBackground
                            border.width: 1
                            border.color: closeMouse.containsMouse ? root.palette.danger : root.palette.frameBorder

                            Text {
                                anchors.centerIn: parent
                                text: "X"
                                color: root.palette.secondaryText
                                font.pixelSize: 11
                                font.bold: true
                            }

                            MouseArea {
                                id: closeMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Qt.quit()
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 30
                        radius: 6
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.frameBorder
                        clip: true

                        Flickable {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            contentWidth: breadcrumbRow.width
                            contentHeight: height
                            flickableDirection: Flickable.HorizontalFlick
                            boundsBehavior: Flickable.StopAtBounds

                            Row {
                                id: breadcrumbRow

                                height: parent.height
                                spacing: 4

                                Repeater {
                                    model: root.breadcrumbs

                                    delegate: Row {
                                        id: crumbWrap

                                        required property var modelData
                                        required property int index

                                        height: breadcrumbRow.height
                                        spacing: 4

                                        Rectangle {
                                            width: Math.min(170, Math.max(34, crumbText.implicitWidth + 20))
                                            height: 24
                                            anchors.verticalCenter: parent.verticalCenter
                                            radius: 6
                                            color: crumbMouse.containsMouse || root.currentPath === crumbWrap.modelData.path
                                                ? root.palette.cardHover
                                                : "transparent"
                                            border.width: root.currentPath === crumbWrap.modelData.path ? 1 : 0
                                            border.color: root.palette.accent

                                            Text {
                                                id: crumbText

                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 8
                                                text: crumbWrap.modelData.label
                                                color: root.currentPath === crumbWrap.modelData.path
                                                    ? root.palette.accentStrong
                                                    : root.palette.secondaryText
                                                font.pixelSize: 11
                                                font.bold: root.currentPath === crumbWrap.modelData.path
                                                horizontalAlignment: Text.AlignHCenter
                                                elide: Text.ElideMiddle
                                            }

                                            MouseArea {
                                                id: crumbMouse

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.navigate(crumbWrap.modelData.path)
                                            }
                                        }

                                        Text {
                                            height: parent.height
                                            visible: crumbWrap.index < root.breadcrumbs.length - 1
                                            text: "/"
                                            color: root.palette.mutedText
                                            font.pixelSize: 11
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        height: 34
                        spacing: 8

                        Rectangle {
                            width: parent.width - hiddenToggle.width - newFolderButton.width - (parent.spacing * 2)
                            height: parent.height
                            radius: 6
                            color: root.palette.cardBackground
                            border.width: 1
                            border.color: filterInput.activeFocus ? root.palette.accent : root.palette.frameBorder

                            TextInput {
                                id: filterInput

                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                text: root.filterText
                                color: root.palette.primaryText
                                selectionColor: Qt.alpha(root.palette.accent, 0.35)
                                selectedTextColor: root.palette.accentStrong
                                font.pixelSize: 13
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                onTextEdited: root.filterText = text
                                onAccepted: root.focusList()
                                Keys.onPressed: function(event) {
                                    if (event.key === Qt.Key_Escape) {
                                        root.clearFilter()
                                        event.accepted = true
                                    } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_L) {
                                        root.focusPathInput()
                                        event.accepted = true
                                    }
                                }
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 10
                                visible: filterInput.text.length === 0 && !filterInput.activeFocus
                                text: "Filter"
                                color: root.palette.mutedText
                                font.pixelSize: 13
                            }
                        }

                        Rectangle {
                            id: newFolderButton

                            width: 112
                            height: parent.height
                            radius: 6
                            color: newFolderMouse.containsMouse && root.actionButtonEnabled("mkdir")
                                ? root.palette.cardHover
                                : root.palette.cardBackground
                            opacity: root.actionButtonEnabled("mkdir") ? 1.0 : 0.45
                            border.width: 1
                            border.color: newFolderMouse.containsMouse && root.actionButtonEnabled("mkdir")
                                ? root.palette.accent
                                : root.palette.frameBorder

                            Text {
                                anchors.centerIn: parent
                                text: "New Folder"
                                color: root.palette.secondaryText
                                font.pixelSize: 12
                                font.bold: true
                            }

                            MouseArea {
                                id: newFolderMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: root.actionButtonEnabled("mkdir") ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (root.actionButtonEnabled("mkdir"))
                                        root.openActionDialog("mkdir")
                                }
                            }
                        }

                        Rectangle {
                            id: hiddenToggle

                            width: 104
                            height: parent.height
                            radius: 6
                            color: hiddenMouse.containsMouse || root.showHidden
                                ? root.palette.cardHover
                                : root.palette.cardBackground
                            border.width: 1
                            border.color: root.showHidden ? root.palette.accent : root.palette.frameBorder

                            Text {
                                anchors.centerIn: parent
                                text: root.showHidden ? "Hidden On" : "Hidden Off"
                                color: root.showHidden ? root.palette.accentStrong : root.palette.secondaryText
                                font.pixelSize: 12
                                font.bold: true
                            }

                            MouseArea {
                                id: hiddenMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.showHidden = !root.showHidden
                            }
                        }
                    }

                    Rectangle {
                        id: listPanel

                        width: parent.width
                        height: parent.height - 34 - 30 - 34 - 28 - (parent.spacing * 4)
                        radius: 8
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.panelBorder
                        clip: true

                        ListView {
                            id: entryList

                            anchors.fill: parent
                            anchors.margins: 8
                            anchors.rightMargin: root.selectedEntry() ? 244 : 8
                            clip: true
                            model: root.visibleEntries
                            currentIndex: 0
                            focus: true
                            boundsBehavior: Flickable.StopAtBounds

                            Keys.onPressed: function(event) {
                                if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_L) {
                                    root.focusPathInput()
                                    event.accepted = true
                                } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_F) {
                                    root.focusFilter()
                                    event.accepted = true
                                } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_R) {
                                    root.refreshCurrent()
                                    event.accepted = true
                                } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_H) {
                                    root.showHidden = !root.showHidden
                                    event.accepted = true
                                } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_N) {
                                    root.openActionDialog("mkdir")
                                    event.accepted = true
                                } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_T) {
                                    root.openTerminalHere()
                                    event.accepted = true
                                } else if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_Left) {
                                    root.goBack()
                                    event.accepted = true
                                } else if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_Right) {
                                    root.goForward()
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    root.activateSelected()
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Up) {
                                    root.selectOffset(-1)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Down) {
                                    root.selectOffset(1)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_PageUp) {
                                    root.selectOffset(-10)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_PageDown) {
                                    root.selectOffset(10)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Home) {
                                    root.selectOffset(-root.visibleEntries.length)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_End) {
                                    root.selectOffset(root.visibleEntries.length)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Backspace) {
                                    root.goUp()
                                    event.accepted = true
                                } else if (event.key === Qt.Key_F2) {
                                    root.openActionDialog("rename")
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Delete) {
                                    root.openActionDialog("trash")
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Escape) {
                                    if (root.filterText.length > 0)
                                        root.clearFilter()
                                    event.accepted = true
                                }
                            }

                            delegate: Rectangle {
                                id: entryRow

                                required property var modelData
                                required property int index
                                readonly property bool selected: root.selectedPath === modelData.path

                                width: entryList.width
                                height: 42
                                radius: 6
                                color: selected || rowMouse.containsMouse
                                    ? root.palette.cardHover
                                    : "transparent"
                                border.width: selected ? 1 : 0
                                border.color: selected ? root.palette.accent : "transparent"

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    Rectangle {
                                        width: 42
                                        height: 28
                                        anchors.verticalCenter: parent.verticalCenter
                                        radius: 6
                                        color: Qt.alpha(themeLoader.actionAccent("files"), 0.16)
                                        border.width: 1
                                        border.color: themeLoader.actionAccent("files")

                                        Text {
                                            anchors.centerIn: parent
                                            text: root.kindIcon(entryRow.modelData.kind)
                                            color: themeLoader.actionAccent("files")
                                            font.pixelSize: 9
                                            font.bold: true
                                        }
                                    }

                                    Column {
                                        width: parent.width - 52
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 1

                                        Text {
                                            width: parent.width
                                            text: entryRow.modelData.name
                                            color: entryRow.selected ? root.palette.accentStrong : root.palette.primaryText
                                            font.pixelSize: 13
                                            font.bold: entryRow.modelData.kind === "directory"
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: parent.width
                                            text: root.metaText(entryRow.modelData)
                                            color: root.palette.mutedText
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                MouseArea {
                                    id: rowMouse

                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: function(mouse) {
                                        root.selectedPath = entryRow.modelData.path
                                        entryList.currentIndex = entryRow.index
                                        entryList.forceActiveFocus()
                                        if (mouse.button === Qt.RightButton) {
                                            var point = entryRow.mapToItem(contentRoot, mouse.x, mouse.y)
                                            root.openContextMenu("item", point.x, point.y, entryRow.modelData)
                                        }
                                    }
                                    onDoubleClicked: function(mouse) {
                                        if (mouse.button === Qt.LeftButton)
                                            root.activate(entryRow.modelData)
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: detailsDrawer

                            visible: root.selectedEntry() !== null
                            width: 228
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 8
                            radius: 8
                            color: root.palette.panelBackground
                            border.width: 1
                            border.color: root.palette.frameBorder

                            Column {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10

                                Text {
                                    width: parent.width
                                    text: "Details"
                                    color: root.palette.primaryText
                                    font.pixelSize: 16
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Row {
                                    width: parent.width
                                    height: 42
                                    spacing: 10

                                    Rectangle {
                                        width: 44
                                        height: 32
                                        anchors.verticalCenter: parent.verticalCenter
                                        radius: 6
                                        color: Qt.alpha(themeLoader.actionAccent("files"), 0.16)
                                        border.width: 1
                                        border.color: themeLoader.actionAccent("files")

                                        Text {
                                            anchors.centerIn: parent
                                            text: root.selectedEntry() ? root.kindIcon(root.selectedEntry().kind) : "--"
                                            color: themeLoader.actionAccent("files")
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                    }

                                    Column {
                                        width: parent.width - 54
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            width: parent.width
                                            text: root.selectedEntry() ? root.selectedEntry().name : ""
                                            color: root.palette.accentStrong
                                            font.pixelSize: 14
                                            font.bold: true
                                            elide: Text.ElideMiddle
                                        }
                                    }
                                }

                                Grid {
                                    id: detailsGrid

                                    width: parent.width
                                    columns: 2
                                    columnSpacing: 10
                                    rowSpacing: 8

                                    Repeater {
                                        model: root.detailsRows()

                                        delegate: Column {
                                            id: detailCell

                                            required property var modelData

                                            width: (detailsGrid.width - detailsGrid.columnSpacing) / 2
                                            spacing: 2

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
                                                text: root.detailsValue(detailCell.modelData.key)
                                                color: root.palette.secondaryText
                                                font.pixelSize: 12
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }

                                Column {
                                    width: parent.width
                                    spacing: 3

                                    Text {
                                        width: parent.width
                                        text: "Path"
                                        color: root.palette.mutedText
                                        font.pixelSize: 10
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        height: 58
                                        text: root.selectedEntry() ? root.selectedEntry().path : ""
                                        color: root.palette.secondaryText
                                        font.pixelSize: 12
                                        wrapMode: Text.WrapAnywhere
                                        maximumLineCount: 3
                                        elide: Text.ElideRight
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 1
                                    color: root.palette.frameBorder
                                }

                                Grid {
                                    id: drawerActionGrid

                                    width: parent.width
                                    columns: 2
                                    columnSpacing: 8
                                    rowSpacing: 7

                                    Repeater {
                                        model: [
                                            {"label": "Open", "action": "open"},
                                            {"label": "Rename", "action": "rename"},
                                            {"label": "Copy Path", "action": "copy-path"},
                                            {"label": "Terminal", "action": "terminal-target"},
                                            {"label": "Trash", "action": "trash"}
                                        ]

                                        delegate: Rectangle {
                                            id: drawerAction

                                            required property var modelData
                                            readonly property bool isTerminal: modelData.action === "terminal-target"
                                            readonly property bool hasSelection: root.selectedEntry() !== null
                                            readonly property bool terminalEnabled: hasSelection && root.selectedEntry().kind === "directory"
                                            readonly property bool enabledAction: hasSelection && (!isTerminal || terminalEnabled)

                                            width: (drawerActionGrid.width - drawerActionGrid.columnSpacing) / 2
                                            height: 30
                                            radius: 6
                                            opacity: enabledAction ? 1.0 : 0.45
                                            color: drawerActionMouse.containsMouse && enabledAction
                                                ? root.palette.cardHover
                                                : root.palette.cardBackground
                                            border.width: 1
                                            border.color: drawerActionMouse.containsMouse && enabledAction
                                                ? (modelData.action === "trash" ? root.palette.danger : root.palette.accent)
                                                : root.palette.frameBorder

                                            Text {
                                                anchors.centerIn: parent
                                                text: drawerAction.modelData.label
                                                color: drawerAction.modelData.action === "trash" && drawerAction.enabledAction
                                                    ? root.palette.danger
                                                    : root.palette.secondaryText
                                                font.pixelSize: 11
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            MouseArea {
                                                id: drawerActionMouse

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: drawerAction.enabledAction ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: {
                                                    if (!drawerAction.enabledAction)
                                                        return
                                                    root.contextMenuTargetPath = root.selectedEntry().path
                                                    root.contextMenuTargetName = root.selectedEntry().name
                                                    root.contextMenuTargetKind = root.selectedEntry().kind
                                                    root.runContextMenuAction(drawerAction.modelData.action)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !root.loading && root.visibleEntries.length === 0
                            text: "No entries"
                            color: root.palette.mutedText
                            font.pixelSize: 14
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton
                            hoverEnabled: false
                            propagateComposedEvents: true
                            onClicked: function(mouse) {
                                var listX = mouse.x - entryList.x
                                var listY = mouse.y - entryList.y
                                var index = entryList.indexAt(listX, listY)
                                var point = listPanel.mapToItem(contentRoot, mouse.x, mouse.y)

                                if (index >= 0 && index < root.visibleEntries.length) {
                                    var entry = root.visibleEntries[index]
                                    root.selectedPath = entry.path
                                    entryList.currentIndex = index
                                    root.openContextMenu("item", point.x, point.y, entry)
                                } else {
                                    root.openContextMenu("background", point.x, point.y, null)
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        height: 28
                        spacing: 10

                        Text {
                            width: parent.width * 0.65
                            height: parent.height
                            text: root.currentPath
                            color: root.palette.secondaryText
                            font.pixelSize: 11
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideMiddle
                        }

                        Text {
                            width: parent.width * 0.15
                            height: parent.height
                            text: root.countLabel()
                            color: root.palette.mutedText
                            font.pixelSize: 11
                            horizontalAlignment: Text.AlignRight
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width * 0.20 - parent.spacing * 2
                            height: parent.height
                            text: root.loading ? "Loading" : root.statusMessage
                            color: root.statusColor()
                            font.pixelSize: 11
                            horizontalAlignment: Text.AlignRight
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: root.contextMenuOpen
                color: "transparent"

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: root.closeContextMenu()
                }

                Rectangle {
                    x: root.contextMenuX
                    y: root.contextMenuY
                    width: 188
                    height: 10 + (root.contextMenuKind === "item" ? 38 : 0) + (root.contextMenuActions.length * 34)
                    radius: 8
                    color: root.palette.cardBackground
                    border.width: 1
                    border.color: root.palette.panelBorder

                    MouseArea {
                        anchors.fill: parent
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 5
                        spacing: 4

                        Rectangle {
                            width: parent.width
                            height: 34
                            visible: root.contextMenuKind === "item"
                            radius: 6
                            color: root.palette.panelBackground
                            border.width: 1
                            border.color: root.palette.frameBorder

                            Text {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                text: root.contextMenuTargetName
                                color: root.palette.primaryText
                                font.pixelSize: 12
                                font.bold: true
                                elide: Text.ElideMiddle
                            }
                        }

                        Repeater {
                            model: root.contextMenuActions

                            delegate: Rectangle {
                                id: menuRow

                                required property var modelData

                                width: parent.width
                                height: 30
                                radius: 6
                                color: menuMouse.containsMouse ? root.palette.cardHover : "transparent"

                                Text {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    text: menuRow.modelData.label
                                    color: menuRow.modelData.tone === "danger"
                                        ? root.palette.danger
                                        : root.palette.secondaryText
                                    font.pixelSize: 12
                                    font.bold: menuRow.modelData.tone === "danger"
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    id: menuMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.runContextMenuAction(menuRow.modelData.action)
                                }
                            }
                        }
                    }
                }

            }

            Rectangle {
                anchors.fill: parent
                visible: root.actionDialogOpen
                color: Qt.alpha("#000000", 0.45)

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.closeActionDialog()
                }

                Rectangle {
                    width: 420
                    height: root.actionDialogMode === "trash" ? 190 : 220
                    anchors.centerIn: parent
                    radius: 8
                    color: root.palette.cardBackground
                    border.width: 1
                    border.color: root.actionDialogMode === "trash" ? root.palette.danger : root.palette.accent

                    MouseArea {
                        anchors.fill: parent
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 12

                        Text {
                            width: parent.width
                            text: root.actionDialogTitle
                            color: root.actionDialogMode === "trash" ? root.palette.danger : root.palette.accentStrong
                            font.pixelSize: 18
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: root.actionDialogMessage
                            color: root.palette.secondaryText
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            width: parent.width
                            height: 36
                            visible: root.actionDialogMode !== "trash"
                            radius: 6
                            color: root.palette.panelBackground
                            border.width: 1
                            border.color: actionInput.activeFocus ? root.palette.accent : root.palette.frameBorder

                            TextInput {
                                id: actionInput

                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                text: root.actionDialogValue
                                color: root.palette.primaryText
                                selectionColor: Qt.alpha(root.palette.accent, 0.35)
                                selectedTextColor: root.palette.accentStrong
                                font.pixelSize: 13
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                onTextEdited: root.actionDialogValue = text
                                onAccepted: root.runDialogAction()
                                Keys.onPressed: function(event) {
                                    if (event.key === Qt.Key_Escape) {
                                        root.closeActionDialog()
                                        event.accepted = true
                                    }
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            height: root.actionDialogMode === "trash" ? 36 : 18
                            text: root.actionDialogMode === "trash"
                                ? "This moves the item to trash, not permanent deletion."
                                : "Names cannot be empty or contain '/'."
                            color: root.palette.mutedText
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            verticalAlignment: Text.AlignVCenter
                        }

                        Row {
                            width: parent.width
                            height: 34
                            spacing: 8

                            Item {
                                width: parent.width - cancelButton.width - confirmButton.width - (parent.spacing * 2)
                                height: parent.height
                            }

                            Rectangle {
                                id: cancelButton

                                width: 88
                                height: parent.height
                                radius: 6
                                color: cancelMouse.containsMouse ? root.palette.cardHover : root.palette.panelBackground
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
                                    id: cancelMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.closeActionDialog()
                                }
                            }

                            Rectangle {
                                id: confirmButton

                                width: 104
                                height: parent.height
                                radius: 6
                                color: confirmMouse.containsMouse ? root.palette.cardHover : root.palette.panelBackground
                                border.width: 1
                                border.color: root.actionDialogMode === "trash" ? root.palette.danger : root.palette.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: root.actionDialogMode === "trash" ? "Move" : "Apply"
                                    color: root.actionDialogMode === "trash" ? root.palette.danger : root.palette.accentStrong
                                    font.pixelSize: 12
                                    font.bold: true
                                }

                                MouseArea {
                                    id: confirmMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.runDialogAction()
                                }

                                Keys.onPressed: function(event) {
                                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        root.runDialogAction()
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Escape) {
                                        root.closeActionDialog()
                                        event.accepted = true
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
