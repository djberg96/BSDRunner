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
    readonly property var visibleEntries: filteredEntries()
    readonly property var breadcrumbs: breadcrumbEntries()
    readonly property var recentShortcuts: recentEntries()

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

                        Text {
                            width: parent.width
                            text: root.palette.name
                            color: root.palette.accent
                            font.pixelSize: 12
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Flickable {
                            width: parent.width
                            height: parent.height - 62
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
                            width: parent.width - hiddenToggle.width - parent.spacing
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
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selectedPath = entryRow.modelData.path
                                        entryList.currentIndex = entryRow.index
                                        entryList.forceActiveFocus()
                                    }
                                    onDoubleClicked: root.activate(entryRow.modelData)
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
        }
    }
}
