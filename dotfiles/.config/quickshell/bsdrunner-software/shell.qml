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
    readonly property string activeTheme: themeLoader.activeTheme
    property string currentView: "browse"
    property string searchQuery: ""
    property string committedSearchQuery: ""
    property string selectedPackageName: ""
    property string statusMessage: "Loading a package page from pkg..."
    property string statusTone: "info"
    property string generatedAt: ""
    property bool loadingPackages: false
    property var packageData: []
    property int pageIndex: 0
    property int pageSize: 12
    property bool hasPreviousPage: false
    property bool hasNextPage: false
    property int loadedCount: 0
    property int installedTotalCount: 0
    property string installedSizeLabel: "0 B"
    property string browseCountLabel: "0"
    property string installedCountLabel: "0"
    property string updatesCountLabel: "--"
    property bool pendingRefresh: false
    property bool refreshButtonHovered: false
    property int snapshotExitCode: 0
    property string snapshotStderrText: ""
    property string snapshotStdoutText: ""
    property bool snapshotExited: false
    property bool snapshotStdoutFinished: false
    property bool snapshotStderrFinished: false
    property string pendingActionId: ""
    property string pendingActionLabel: ""
    property string pendingActionPackageName: ""
    property string activeActionId: ""
    property string activeActionLabel: ""
    property string activeActionPackageName: ""
    property bool runningAction: false
    property int actionExitCode: 0
    property string actionStdoutText: ""
    property string actionStderrText: ""
    property bool actionExited: false
    property bool actionStdoutFinished: false
    property bool actionStderrFinished: false
    property string actionFeedbackTone: "info"
    property string actionFeedbackTitle: ""
    property string actionFeedbackDetails: ""
    readonly property var visiblePackages: packageData
    readonly property var selectedPackage: findPackage(selectedPackageName)
    readonly property string appVersion: "1.0.1"
    readonly property var protectedPackageNames: [
        "dbus",
        "dolphin",
        "foot",
        "hyprland",
        "hyprlauncher",
        "kitty",
        "librsvg2",
        "librsvg2-rust",
        "mate-polkit",
        "polkit",
        "quickshell",
        "rofi",
        "rofi-wayland",
        "seatd",
        "swww",
        "waybar",
        "wlogout",
        "xdg-desktop-portal",
        "xdg-desktop-portal-gtk",
        "xdg-desktop-portal-hyprland",
        "xdg-utils"
    ]

    function normalize(value) {
        return (value || "").toLowerCase()
    }

    function findPackage(name) {
        for (var i = 0; i < packageData.length; i += 1) {
            if (packageData[i].name === name)
                return packageData[i]
        }

        return null
    }

    function packageInList(name, list) {
        for (var i = 0; i < list.length; i += 1) {
            if (list[i].name === name)
                return true
        }

        return false
    }

    function viewTitle() {
        switch (currentView) {
        case "installed":
            return "Browse Installed Packages"
        case "updates":
            return "Browse Package Updates"
        default:
            return "Browse All Packages"
        }
    }

    function installedCount() {
        var count = 0
        for (var i = 0; i < packageData.length; i += 1) {
            if (packageData[i].installed)
                count += 1
        }
        return count
    }

    function updateCount() {
        return 0
    }

    function pageLabel() {
        return "Page " + (pageIndex + 1)
    }

    function statusSearchText() {
        if (!committedSearchQuery || committedSearchQuery.length === 0)
            return "No filter"

        return "Filter: " + committedSearchQuery
    }

    function setView(nextView) {
        if (currentView === nextView || runningAction)
            return

        clearPendingAction()
        currentView = nextView
        pageIndex = 0
        refreshPackages()
    }

    function clearPendingAction() {
        pendingActionId = ""
        pendingActionLabel = ""
        pendingActionPackageName = ""
    }

    function clearActionFeedback() {
        actionFeedbackTone = "info"
        actionFeedbackTitle = ""
        actionFeedbackDetails = ""
    }

    function selectPackage(pkgName) {
        if (!pkgName || runningAction)
            return

        if (selectedPackageName === pkgName)
            return

        clearPendingAction()
        clearActionFeedback()
        selectedPackageName = pkgName
    }

    function requestAction(actionId, actionLabel, pkgName) {
        if (runningAction || !pkgName)
            return

        clearActionFeedback()
        pendingActionId = actionId
        pendingActionLabel = actionLabel
        pendingActionPackageName = pkgName
    }

    function confirmationText() {
        if (!pendingActionPackageName || pendingActionPackageName.length === 0)
            return ""

        switch (pendingActionId) {
        case "install":
            return "Install " + pendingActionPackageName + " from the configured FreeBSD package repositories?"
        case "reinstall":
            return "Reinstall " + pendingActionPackageName + " from the configured FreeBSD package repositories?"
        case "upgrade":
            return "Upgrade " + pendingActionPackageName + " to the latest available package version?"
        case "remove":
            return "Remove " + pendingActionPackageName + " from this system?"
        default:
            return ""
        }
    }

    function runConfirmedAction() {
        if (!pendingActionId || !pendingActionPackageName || runningAction)
            return

        activeActionId = pendingActionId
        activeActionLabel = pendingActionLabel
        activeActionPackageName = pendingActionPackageName
        clearPendingAction()

        runningAction = true
        actionExitCode = 0
        actionStdoutText = ""
        actionStderrText = ""
        actionExited = false
        actionStdoutFinished = false
        actionStderrFinished = false

        actionFeedbackTone = "warning"
        actionFeedbackTitle = "Running " + activeActionLabel + " for " + activeActionPackageName
        actionFeedbackDetails = "Working..."
        actionProcess.running = true
    }

    function maybeFinalizeAction() {
        if (!actionExited || !actionStdoutFinished || !actionStderrFinished)
            return

        applyActionResult(actionStdoutText, actionExitCode, actionStderrText)
    }

    function applyActionResult(text, exitCode, stderrText) {
        runningAction = false

        var lines = (text || "").split(/\r?\n/)
        var compact = []
        for (var i = 0; i < lines.length; i += 1) {
            if (lines[i].trim().length > 0)
                compact.push(lines[i])
        }

        var payload = null
        var logText = ""
        if (compact.length > 0) {
            var jsonLine = compact[compact.length - 1]
            logText = compact.slice(0, compact.length - 1).join("\n")
            try {
                payload = JSON.parse(jsonLine)
            } catch (error) {
                payload = null
                logText = compact.join("\n")
            }
        }

        var payloadDetails = payload && payload.details ? payload.details.trim() : ""
        var payloadLogPath = payload && payload.log_path ? payload.log_path.trim() : ""
        var detailText = ""
        if (payload) {
            detailText = payloadDetails
            if (!payload.ok && detailText.length === 0 && payloadLogPath.length > 0)
                detailText = "See log: " + payloadLogPath
        } else {
            detailText = logText
            if (stderrText && stderrText.trim().length > 0)
                detailText = detailText.length > 0 ? detailText + "\n" + stderrText.trim() : stderrText.trim()
        }

        var compactDetail = detailText.trim()
        var firstDetailLine = ""
        if (compactDetail.length > 0)
            firstDetailLine = compactDetail.split(/\r?\n/)[0]

        if (payload && payload.ok && exitCode === 0) {
            actionFeedbackTone = "success"
            actionFeedbackTitle = payload.message || (activeActionLabel + " completed for " + activeActionPackageName + ".")
            actionFeedbackDetails = compactDetail
            applyOptimisticActionState(activeActionId, activeActionPackageName)
            statusTone = "info"
            statusMessage = "Refreshing package metadata..."
            refreshPackages(false)
        } else {
            actionFeedbackTone = "error"
            actionFeedbackTitle = payload && payload.message
                ? payload.message
                : "Package action failed."
            actionFeedbackDetails = compactDetail.length > 0
                ? compactDetail
                : "No additional error details were returned."
            statusTone = "error"
            statusMessage = firstDetailLine.length > 0 ? firstDetailLine : actionFeedbackTitle
        }

        activeActionId = ""
        activeActionLabel = ""
        activeActionPackageName = ""
    }

    function isTruthyFlag(value) {
        if (value === true)
            return true

        if (value === false || value === null || value === undefined)
            return false

        if (typeof value === "number")
            return value !== 0

        var normalizedValue = String(value).toLowerCase()
        return normalizedValue === "1"
            || normalizedValue === "true"
            || normalizedValue === "yes"
            || normalizedValue === "on"
    }

    function isInstalledPackage(pkg) {
        return !!pkg && isTruthyFlag(pkg.installed)
    }

    function isProtectedPackage(pkg) {
        if (!pkg || !pkg.name)
            return false

        return protectedPackageNames.indexOf(pkg.name) !== -1
    }

    function hasAvailableUpgrade(pkg) {
        return !!pkg && isInstalledPackage(pkg) && isTruthyFlag(pkg.update_available)
    }

    function copyPackageRecord(pkg) {
        var copy = {}
        for (var key in pkg)
            copy[key] = pkg[key]
        return copy
    }

    function applyOptimisticActionState(actionId, pkgName) {
        if (!pkgName || pkgName.length === 0)
            return

        var nextPackages = []
        var installedDelta = 0
        var updatesDelta = 0

        for (var i = 0; i < packageData.length; i += 1) {
            var current = packageData[i]
            if (current.name !== pkgName) {
                nextPackages.push(current)
                continue
            }

            var updated = copyPackageRecord(current)
            var wasInstalled = isInstalledPackage(current)

            switch (actionId) {
            case "install":
                if (!wasInstalled)
                    installedDelta += 1
                updated.installed = true
                updated.installed_version = updated.version || updated.installed_version
                updated.update_available = false
                break
            case "reinstall":
                updated.installed = true
                updated.installed_version = updated.version || updated.installed_version
                updated.update_available = false
                break
            case "upgrade":
                if (hasAvailableUpgrade(current))
                    updatesDelta -= 1
                updated.installed = true
                updated.installed_version = updated.version || updated.installed_version
                updated.update_available = false
                break
            case "remove":
                if (wasInstalled)
                    installedDelta -= 1
                if (hasAvailableUpgrade(current))
                    updatesDelta -= 1
                updated.installed = false
                updated.installed_version = ""
                updated.update_available = false
                if (currentView === "installed")
                    continue
                break
            }

            if (currentView === "updates" && actionId === "upgrade")
                continue

            nextPackages.push(updated)
        }

        packageData = nextPackages
        if (installedDelta !== 0) {
            installedTotalCount = Math.max(0, installedTotalCount + installedDelta)
            installedCountLabel = String(installedTotalCount)
        }
        if (updatesDelta !== 0 && updatesCountLabel !== "--") {
            var parsedUpdates = Number(updatesCountLabel)
            if (!isNaN(parsedUpdates))
                updatesCountLabel = String(Math.max(0, parsedUpdates + updatesDelta))
        }

        installedSizeLabel = "Refreshing..."
    }

    function versionText(pkg) {
        if (!pkg)
            return ""
        if (hasAvailableUpgrade(pkg) && pkg.installed_version && pkg.installed_version !== pkg.version)
            return pkg.installed_version + " -> " + pkg.version
        if (isInstalledPackage(pkg) && pkg.installed_version)
            return pkg.installed_version
        return pkg.version || ""
    }

    function formatLicense(value) {
        var raw = (value || "").trim()
        if (raw.length === 0 || raw === "Unknown")
            return "Unknown"

        var replacements = {
            "APACHE20": "Apache 2.0",
            "APACHE11": "Apache 1.1",
            "BSD2CLAUSE": "BSD 2-Clause",
            "BSD3CLAUSE": "BSD 3-Clause",
            "GPLV2": "GPL v2",
            "GPLV3": "GPL v3",
            "LGPL21": "LGPL 2.1",
            "LGPL3": "LGPL 3.0",
            "MIT": "MIT",
            "MPL20": "MPL 2.0",
            "ISCL": "ISC",
            "PD": "Public Domain"
        }

        var display = raw
        for (var key in replacements)
            display = display.replace(new RegExp("\\b" + key + "\\b", "g"), replacements[key])

        display = display.replace(/\|/g, " or ")
        display = display.replace(/&/g, " and ")
        display = display.replace(/,/g, ", ")
        return display
    }

    function refreshPackages(clearSelection) {
        if (snapshotProcess.running) {
            pendingRefresh = true
            return
        }

        loadingPackages = true
        pendingRefresh = false
        statusTone = "info"
        statusMessage = "Loading a package page from pkg..."
        snapshotExitCode = 0
        snapshotStderrText = ""
        snapshotStdoutText = ""
        snapshotExited = false
        snapshotStdoutFinished = false
        snapshotStderrFinished = false
        if (clearSelection !== false)
            selectedPackageName = ""
        snapshotProcess.running = true
    }

    function maybeFinalizeSnapshot() {
        if (!snapshotExited || !snapshotStdoutFinished || !snapshotStderrFinished)
            return

        root.applySnapshot(root.snapshotStdoutText, root.snapshotExitCode, root.snapshotStderrText)
    }

    function applySnapshot(text, exitCode, stderrText) {
        var payload = null

        if (!text || text.trim().length === 0) {
            statusTone = "error"
            statusMessage = stderrText && stderrText.trim().length > 0
                ? stderrText.trim()
                : "The pkg backend returned no data."
            packageData = []
            loadedCount = 0
            installedSizeLabel = "0 B"
            hasPreviousPage = pageIndex > 0
            hasNextPage = false
            generatedAt = ""
            loadingPackages = false
            if (pendingRefresh)
                refreshPackages()
            return
        }

        try {
            payload = JSON.parse(text)
        } catch (error) {
            statusTone = "error"
            statusMessage = "The pkg backend returned invalid JSON."
            packageData = []
            loadedCount = 0
            installedSizeLabel = "0 B"
            hasPreviousPage = pageIndex > 0
            hasNextPage = false
            generatedAt = ""
            loadingPackages = false
            if (pendingRefresh)
                refreshPackages()
            return
        }

        if (exitCode !== 0 || !payload.ok) {
            statusTone = "error"
            statusMessage = payload.message || stderrText || "Unable to load pkg metadata."
            packageData = []
            loadedCount = 0
            installedSizeLabel = "0 B"
            hasPreviousPage = pageIndex > 0
            hasNextPage = false
            generatedAt = ""
            loadingPackages = false
            if (pendingRefresh)
                refreshPackages()
            return
        }

        packageData = payload.packages || []
        generatedAt = payload.generated_at || ""
        loadedCount = payload.summary && payload.summary.loaded ? payload.summary.loaded : packageData.length
        installedTotalCount = payload.summary && payload.summary.installed ? payload.summary.installed : 0
        hasPreviousPage = payload.summary ? !!payload.summary.has_prev : pageIndex > 0
        hasNextPage = payload.summary ? !!payload.summary.has_next : false
        browseCountLabel = payload.summary && payload.summary.browse_count_label
            ? payload.summary.browse_count_label
            : String(packageData.length)
        installedCountLabel = payload.summary && payload.summary.installed_count_label
            ? payload.summary.installed_count_label
            : String(installedTotalCount)
        installedSizeLabel = payload.summary && payload.summary.installed_size_label
            ? payload.summary.installed_size_label
            : "0 B"
        updatesCountLabel = payload.summary && payload.summary.updates_count_label
            ? payload.summary.updates_count_label
            : "--"
        statusTone = "info"
        statusMessage = payload.message || "Loaded package metadata from pkg."
        loadingPackages = false
        if (pendingRefresh)
            refreshPackages()
    }

    onVisiblePackagesChanged: {
        if (visiblePackages.length === 0) {
            selectedPackageName = ""
        } else if (!packageInList(selectedPackageName, visiblePackages)) {
            selectedPackageName = visiblePackages[0].name
        }
    }

    Component.onCompleted: refreshPackages()

    Timer {
        id: searchDebounce

        interval: 250
        repeat: false
        onTriggered: {
            root.committedSearchQuery = root.searchQuery
            root.pageIndex = 0
            root.refreshPackages()
        }
    }

    Process {
        id: snapshotProcess
        property var controller: root

        command: [
            "sh",
            themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-software-backend.sh",
            "snapshot",
            root.currentView,
            String(root.pageIndex),
            String(root.pageSize),
            root.committedSearchQuery
        ]
        stdout: StdioCollector {
            id: snapshotStdout
            waitForEnd: true

            onStreamFinished: {
                snapshotProcess.controller.snapshotStdoutText = text
                snapshotProcess.controller.snapshotStdoutFinished = true
                snapshotProcess.controller.maybeFinalizeSnapshot()
            }
        }
        stderr: StdioCollector {
            id: snapshotStderr
            waitForEnd: true

            onStreamFinished: {
                snapshotProcess.controller.snapshotStderrFinished = true
                snapshotProcess.controller.snapshotStderrText = text
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
            themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-software-backend.sh",
            root.activeActionId,
            root.activeActionPackageName
        ]
        stdout: StdioCollector {
            id: actionStdout
            waitForEnd: true

            onStreamFinished: {
                actionProcess.controller.actionStdoutText = text
                actionProcess.controller.actionStdoutFinished = true
                actionProcess.controller.maybeFinalizeAction()
            }
        }
        stderr: StdioCollector {
            id: actionStderr
            waitForEnd: true

            onStreamFinished: {
                actionProcess.controller.actionStderrFinished = true
                actionProcess.controller.actionStderrText = text
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
        title: "BSDRunner Software"
        implicitWidth: 1160
        implicitHeight: 680
        minimumSize: Qt.size(1160, 680)
        maximumSize: Qt.size(1160, 680)
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 0
            color: root.palette.panelBackground
            border.width: 0
            border.color: root.palette.frameBorder

            Row {
                id: contentRow

                anchors.fill: parent
                anchors.margins: 16
                spacing: 18

                Rectangle {
                    id: leftRail

                    width: 216
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    radius: 20
                    color: root.palette.cardBackground
                    border.width: 1
                    border.color: root.palette.panelBorder

                    Column {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.topMargin: 20
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        anchors.bottomMargin: 42
                        spacing: 16

                        Column {
                            spacing: 0

                            Text {
                                text: "Browse:"
                                color: root.palette.primaryText
                                font.pixelSize: 34
                                font.bold: true
                            }
                        }

                            Column {
                                spacing: 10

                                Repeater {
                                    model: [
                                        {
                                            "id": "browse",
                                            "label": "All",
                                            "count": root.browseCountLabel,
                                            "accent": root.palette.accent,
                                            "hint": "Browse the full FreeBSD package catalog."
                                        },
                                        {
                                            "id": "installed",
                                            "label": "Installed",
                                            "count": root.installedCountLabel,
                                            "accent": root.palette.success,
                                            "hint": "Show packages already installed on this system."
                                        },
                                        {
                                            "id": "updates",
                                            "label": "Updates",
                                            "count": root.updatesCountLabel,
                                            "accent": root.palette.warning,
                                            "hint": "Show installed packages with available updates."
                                        }
                                    ]

                                    delegate: Rectangle {
                                        id: navCard

                                        required property var modelData
                                        readonly property bool active: root.currentView === modelData.id

                                        width: 176
                                        height: 66
                                        radius: 16
                                        z: navMouse.containsMouse ? 10 : 0
                                        color: navCard.active ? root.palette.cardHover : root.palette.panelBackground
                                        border.width: 2
                                        border.color: navCard.active ? navCard.modelData.accent : root.palette.frameBorder

                                        Row {
                                            anchors.fill: parent
                                            anchors.margins: 14
                                            spacing: 12

                                            Rectangle {
                                                width: 38
                                                height: 38
                                                radius: 12
                                                color: navCard.modelData.accent
                                                opacity: navCard.active ? 0.22 : 0.14

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: navCard.modelData.count
                                                    color: navCard.modelData.accent
                                                    font.pixelSize: String(navCard.modelData.count).length > 2 ? 12 : 14
                                                    font.bold: true
                                                }
                                            }

                                            Column {
                                                width: parent.width - 38 - parent.spacing
                                                y: Math.round((parent.height - height) / 2)
                                                spacing: 2

                                                Text {
                                                    text: navCard.modelData.label
                                                    color: root.palette.primaryText
                                                    font.pixelSize: 17
                                                    font.bold: true
                                                }

                                                Text {
                                                    text: navCard.active ? "Current view" : "Switch view"
                                                    color: root.palette.mutedText
                                                    font.pixelSize: 12
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: navMouse

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            enabled: !root.runningAction
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                                            onEntered: parent.color = root.palette.cardHover
                                            onExited: parent.color = parent.active ? root.palette.cardHover : root.palette.panelBackground
                                            onClicked: root.setView(parent.modelData.id)
                                        }

                                        Rectangle {
                                            visible: navMouse.containsMouse && navMouse.enabled
                                            readonly property bool showAbove: navCard.modelData.id === "updates"
                                            x: 0
                                            y: showAbove ? (-height - 8) : (parent.height + 8)
                                            width: navCard.width
                                            height: navHintText.implicitHeight + 20
                                            radius: 12
                                            color: root.palette.cardBackground
                                            border.width: 1
                                            border.color: root.palette.panelBorder
                                            z: 20

                                            Text {
                                                id: navHintText

                                                anchors.fill: parent
                                                anchors.margins: 10
                                                text: navCard.modelData.hint
                                                wrapMode: Text.WordWrap
                                                color: root.palette.secondaryText
                                                font.pixelSize: 11
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: themeCard

                                width: parent.width
                                height: 248
                                radius: 18
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.frameBorder

                                Text {
                                    id: themeCardLabel

                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.topMargin: 16
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    text: "Local Package Status"
                                    color: root.palette.mutedText
                                    font.pixelSize: 12
                                    font.bold: true
                                }

                                Column {
                                    id: statusMetricRow

                                    anchors.top: themeCardLabel.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.topMargin: 8
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    spacing: 8

                                    Repeater {
                                        model: [
                                            {
                                                "label": "Loaded",
                                                "value": root.loadedCount
                                            },
                                            {
                                                "label": "Installed",
                                                "value": root.installedTotalCount
                                            },
                                            {
                                                "label": "Disk Used",
                                                "value": root.installedSizeLabel
                                            }
                                        ]

                                        delegate: Column {
                                            id: statusMetricColumn

                                            required property var modelData

                                            width: statusMetricRow.width
                                            spacing: 2

                                            Text {
                                                width: parent.width
                                                text: statusMetricColumn.modelData.label
                                                color: root.palette.secondaryText
                                                font.pixelSize: 11
                                                font.bold: true
                                            }

                                            Text {
                                                width: parent.width
                                                text: statusMetricColumn.modelData.value
                                                color: root.palette.accentStrong
                                                font.pixelSize: String(statusMetricColumn.modelData.value).length > 8 ? 15 : 18
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    id: themeRefreshButton

                                    anchors.left: parent.left
                                    anchors.bottom: parent.bottom
                                    anchors.leftMargin: 16
                                    anchors.bottomMargin: 18
                                    width: 144
                                    height: 34
                                    radius: 12
                                    color: root.loadingPackages ? root.palette.panelBackground : root.palette.accent
                                    opacity: root.loadingPackages ? 0.24 : 1.0
                                    border.width: root.loadingPackages ? 1 : 2
                                    border.color: root.palette.accent

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.loadingPackages ? "Refreshing" : "Refresh Info"
                                        color: root.loadingPackages ? root.palette.accent : root.palette.frameBackground
                                        font.pixelSize: 12
                                        font.bold: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: !root.loadingPackages && !root.runningAction && root.pendingActionId.length === 0
                                        hoverEnabled: true
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                                        onEntered: root.refreshButtonHovered = true
                                        onExited: root.refreshButtonHovered = false
                                        onClicked: root.refreshPackages()
                                    }
                                }

                                Rectangle {
                                    visible: root.refreshButtonHovered && !root.loadingPackages
                                    anchors.left: themeRefreshButton.left
                                    anchors.top: themeRefreshButton.bottom
                                    anchors.topMargin: 8
                                    width: 176
                                    height: 42
                                    radius: 12
                                    color: root.palette.cardBackground
                                    border.width: 1
                                    border.color: root.palette.panelBorder

                                    Text {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        wrapMode: Text.WordWrap
                                        text: "Refreshes this view with the latest pkg data."
                                        color: root.palette.secondaryText
                                        font.pixelSize: 11
                                    }
                                }

                                Text {
                                    anchors.top: statusMetricRow.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: themeRefreshButton.top
                                    anchors.topMargin: 8
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    anchors.bottomMargin: 18
                                    wrapMode: Text.WordWrap
                                    clip: true
                                    text: root.loadingPackages
                                        ? "Loading a smaller package page from pkg right now."
                                        : root.generatedAt.length > 0
                                            ? root.statusSearchText() + " • Last pkg page: " + root.generatedAt
                                            : "Package data will appear here after the first successful page loads."
                                    color: root.palette.secondaryText
                                    font.pixelSize: 13
                                }
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 16
                            anchors.bottomMargin: 12
                            text: root.appVersion
                            color: root.palette.mutedText
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }

                        Column {
                            id: centerColumn

                            width: contentRow.width - leftRail.width - detailPane.width - (contentRow.spacing * 2)
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            spacing: 16

                            Column {
                                id: centerHeader

                                width: parent.width
                                spacing: 0

                                Text {
                                    width: parent.width
                                    text: root.viewTitle()
                                    color: root.palette.primaryText
                                    font.pixelSize: 34
                                    font.bold: true
                                }
                            }

                        Rectangle {
                            id: searchBarFrame

                            width: parent.width
                            height: 60
                            radius: 18
                            color: root.palette.cardBackground
                            border.width: 1
                            border.color: root.palette.panelBorder

                            TextInput {
                                id: searchInput
                                anchors.fill: parent
                                anchors.margins: 18
                                color: root.palette.primaryText
                                selectionColor: root.palette.accent
                                selectedTextColor: root.palette.frameBackground
                                font.pixelSize: 16
                                clip: true
                                text: root.searchQuery
                                readOnly: root.runningAction

                                onTextChanged: {
                                    root.clearPendingAction()
                                    root.searchQuery = text
                                    searchDebounce.restart()
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: parent.text.length === 0
                                    text: "Search or filter - package:, category:, installed:"
                                    color: root.palette.mutedText
                                    font.pixelSize: 16
                                }
                            }
                        }

                        Rectangle {
                            id: paginationBar

                            width: parent.width
                            height: root.statusTone !== "info" ? 78 : 48
                            radius: 16
                            color: root.palette.cardBackground
                            border.width: 1
                            border.color: root.palette.panelBorder

                            Column {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8

                                Row {
                                    width: parent.width
                                    spacing: 10

                                    Text {
                                        width: 92
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.pageLabel()
                                        color: root.palette.primaryText
                                        font.pixelSize: 15
                                        font.bold: true
                                    }

                                    Row {
                                        width: 236
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 8

                                        Rectangle {
                                            width: 10
                                            height: 10
                                            radius: 5
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: root.statusTone === "error"
                                                ? root.palette.danger
                                                : root.statusTone === "warning"
                                                    ? root.palette.warning
                                                    : root.statusTone === "success"
                                                        ? root.palette.success
                                                    : root.palette.accent
                                            opacity: root.loadingPackages ? 0.95 : 0.65
                                        }

                                        Text {
                                            width: 218
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: root.loadingPackages ? "Loading..." : root.statusSearchText()
                                            color: root.palette.secondaryText
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Item {
                                        width: Math.max(0, parent.width - 92 - 236 - 220 - (parent.spacing * 3))
                                        height: 1
                                    }

                                    Rectangle {
                                        width: 96
                                        height: 24
                                        radius: 12
                                        color: root.hasPreviousPage && !root.loadingPackages
                                            ? root.palette.panelBackground
                                            : root.palette.panelBackground
                                        border.width: root.hasPreviousPage && !root.loadingPackages ? 2 : 1
                                        border.color: root.hasPreviousPage && !root.loadingPackages
                                            ? root.palette.primaryText
                                            : root.palette.frameBorder
                                        opacity: root.hasPreviousPage && !root.loadingPackages && !root.runningAction && root.pendingActionId.length === 0 ? 1.0 : 0.45

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Previous"
                                            color: root.palette.primaryText
                                            font.pixelSize: 12
                                            font.bold: true
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: root.hasPreviousPage && !root.loadingPackages && !root.runningAction && root.pendingActionId.length === 0
                                            hoverEnabled: true
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: {
                                                root.pageIndex -= 1
                                                root.refreshPackages()
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: 96
                                        height: 24
                                        radius: 12
                                        color: root.hasNextPage && !root.loadingPackages && !root.runningAction && root.pendingActionId.length === 0
                                            ? root.palette.accent
                                            : root.palette.panelBackground
                                        border.width: root.hasNextPage && !root.loadingPackages && !root.runningAction && root.pendingActionId.length === 0 ? 2 : 1
                                        border.color: root.hasNextPage && !root.loadingPackages && !root.runningAction && root.pendingActionId.length === 0
                                            ? root.palette.accent
                                            : root.palette.frameBorder
                                        opacity: root.hasNextPage && !root.loadingPackages && !root.runningAction && root.pendingActionId.length === 0 ? 1.0 : 0.10

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Next"
                                            color: root.hasNextPage && !root.loadingPackages && !root.runningAction && root.pendingActionId.length === 0
                                                ? root.palette.accentStrong
                                                : root.palette.mutedText
                                            font.pixelSize: 12
                                            font.bold: true
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: root.hasNextPage && !root.loadingPackages && !root.runningAction && root.pendingActionId.length === 0
                                            hoverEnabled: true
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: {
                                                root.pageIndex += 1
                                                root.refreshPackages()
                                            }
                                        }
                                    }
                                }

                                Text {
                                    visible: root.statusTone !== "info"
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    text: root.statusMessage
                                    color: root.statusTone === "error"
                                        ? root.palette.danger
                                        : root.statusTone === "warning"
                                            ? root.palette.warning
                                            : root.palette.success
                                    font.pixelSize: 12
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: centerColumn.height - centerHeader.height - searchBarFrame.height - paginationBar.height - (centerColumn.spacing * 3)
                            radius: 20
                            color: root.palette.cardBackground
                            border.width: 1
                            border.color: root.palette.panelBorder

                            Item {
                                anchors.fill: parent
                                anchors.margins: 16

                                Column {
                                    id: emptyState
                                    anchors.centerIn: parent
                                    width: 280
                                    spacing: 8
                                    visible: root.visiblePackages.length === 0

                                    Text {
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        text: root.statusTone === "error"
                                            ? "pkg metadata is unavailable."
                                            : "No packages match this view."
                                        color: root.palette.primaryText
                                        font.pixelSize: 22
                                        font.bold: true
                                    }

                                    Text {
                                        width: parent.width
                                        wrapMode: Text.WordWrap
                                        horizontalAlignment: Text.AlignHCenter
                                        text: root.statusTone === "error"
                                            ? "Check the status banner above, then refresh pkg when the backend is ready."
                                            : "Try clearing the search box or switch to another package view."
                                        color: root.palette.secondaryText
                                        font.pixelSize: 14
                                    }
                                }

                                Flickable {
                                    id: packageFlickable

                                    anchors.fill: parent
                                    contentWidth: width
                                    contentHeight: packageColumn.height
                                    boundsBehavior: Flickable.StopAtBounds
                                    clip: true
                                    interactive: contentHeight > height
                                    visible: root.visiblePackages.length > 0

                                    Column {
                                        id: packageColumn
                                        width: parent.width
                                        spacing: 10

                                        Repeater {
                                            model: root.visiblePackages

                                            delegate: Rectangle {
                                                id: packageCard

                                                required property var modelData
                                                readonly property var pkg: modelData
                                                readonly property bool active: root.selectedPackageName === pkg.name
                                                readonly property bool hovered: packageMouse.containsMouse

                                                width: packageColumn.width
                                                height: 82
                                                radius: 18
                                                color: active || hovered ? root.palette.cardHover : root.palette.panelBackground
                                                border.width: 1
                                                border.color: active ? root.palette.accent : hovered ? root.palette.panelBorder : root.palette.frameBorder

                                                Column {
                                                    anchors.fill: parent
                                                    anchors.margins: 16
                                                    spacing: 8

                                                    Row {
                                                        id: packageHeaderRow

                                                        width: parent.width
                                                        spacing: 10

                                                        Text {
                                                            width: packageHeaderRow.width
                                                                - (installedMarker.visible ? installedMarker.implicitWidth + packageHeaderRow.spacing : 0)
                                                                - categoryBadge.width
                                                                - packageHeaderRow.spacing
                                                                - (updateBadge.visible ? updateBadge.width + packageHeaderRow.spacing : 0)
                                                            height: 24
                                                            text: packageCard.pkg.name
                                                            color: root.palette.primaryText
                                                            font.pixelSize: 20
                                                            minimumPixelSize: 13
                                                            fontSizeMode: Text.HorizontalFit
                                                            font.bold: true
                                                            wrapMode: Text.NoWrap
                                                            elide: Text.ElideNone
                                                        }

                                                        Text {
                                                            id: installedMarker

                                                            visible: root.currentView === "browse" && root.isInstalledPackage(packageCard.pkg)
                                                            height: 24
                                                            text: root.isProtectedPackage(packageCard.pkg) ? "🔒" : "*"
                                                            color: root.isProtectedPackage(packageCard.pkg) ? root.palette.warning : root.palette.success
                                                            font.pixelSize: root.isProtectedPackage(packageCard.pkg) ? 15 : 18
                                                            font.bold: true
                                                            verticalAlignment: Text.AlignVCenter
                                                            horizontalAlignment: Text.AlignHCenter
                                                        }

                                                        Rectangle {
                                                            id: categoryBadge

                                                            width: categoryText.implicitWidth + 20
                                                            height: 24
                                                            radius: 0
                                                            color: Qt.alpha(root.palette.accent, 0.2)
                                                            border.width: 1
                                                            border.color: root.palette.accent

                                                            Text {
                                                                id: categoryText
                                                                anchors.centerIn: parent
                                                                text: packageCard.pkg.category
                                                                color: root.palette.accentStrong
                                                                font.pixelSize: 12
                                                                font.bold: true
                                                            }
                                                        }

                                                        Rectangle {
                                                            id: updateBadge

                                                            visible: root.hasAvailableUpgrade(packageCard.pkg)
                                                            width: 72
                                                            height: 24
                                                            radius: 12
                                                            color: root.palette.warning
                                                            opacity: 0.16

                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: "Update"
                                                                color: root.palette.warning
                                                                font.pixelSize: 12
                                                                font.bold: true
                                                            }
                                                        }
                                                    }

                                                    Text {
                                                        width: parent.width
                                                        wrapMode: Text.WordWrap
                                                        text: packageCard.pkg.comment
                                                        color: root.palette.secondaryText
                                                        font.pixelSize: 14
                                                    }
                                                }

                                                MouseArea {
                                                    id: packageMouse
                                                    anchors.fill: parent
                                                    enabled: !root.runningAction && root.pendingActionId.length === 0
                                                    hoverEnabled: enabled
                                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                                                    onClicked: root.selectPackage(parent.modelData.name)
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        visible: packageFlickable.contentHeight > packageFlickable.height
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        width: 6
                                        radius: 3
                                        color: root.palette.frameBorder
                                        opacity: 0.32

                                        Rectangle {
                                            width: parent.width
                                            radius: 3
                                            color: root.palette.accent
                                            opacity: 0.78
                                            height: Math.max(36, parent.height * (packageFlickable.height / Math.max(packageFlickable.contentHeight, 1)))
                                            y: (parent.height - height) * (packageFlickable.contentY / Math.max(packageFlickable.contentHeight - packageFlickable.height, 1))
                                        }
                                    }
                                }
                            }
                        }
                }

                Rectangle {
                    id: detailPane

                    width: 304
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    radius: 20
                    color: root.palette.cardBackground
                    border.width: 1
                    border.color: root.palette.panelBorder

                    Flickable {
                        id: detailFlickable

                        anchors.fill: parent
                        anchors.margins: 20
                        contentWidth: width
                        contentHeight: detailColumn.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        interactive: contentHeight > height

                        Column {
                            id: detailColumn

                            width: parent.width
                            spacing: 14

                            Rectangle {
                                visible: root.actionFeedbackTitle.length > 0
                                width: parent.width
                                height: actionFeedbackColumn.implicitHeight + 22
                                radius: 14
                                color: root.palette.cardBackground
                                border.width: 1
                                border.color: root.actionFeedbackTone === "error"
                                    ? root.palette.danger
                                    : root.actionFeedbackTone === "success"
                                        ? root.palette.success
                                        : root.palette.warning

                                Column {
                                    id: actionFeedbackColumn

                                    anchors.fill: parent
                                    anchors.margins: 11
                                    spacing: 8

                                    Text {
                                        width: parent.width
                                        text: root.actionFeedbackTitle
                                        color: root.palette.primaryText
                                        font.pixelSize: 13
                                        font.bold: true
                                        wrapMode: Text.WordWrap
                                    }

                                    Text {
                                        width: parent.width
                                        visible: root.actionFeedbackDetails.length > 0
                                        text: root.actionFeedbackDetails
                                        color: root.actionFeedbackTone === "error"
                                            ? root.palette.danger
                                            : root.palette.secondaryText
                                        font.pixelSize: 12
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                height: 38
                                text: root.selectedPackage ? root.selectedPackage.name : "No package selected"
                                color: root.palette.primaryText
                                font.pixelSize: 30
                                minimumPixelSize: 18
                                fontSizeMode: Text.HorizontalFit
                                font.bold: true
                                wrapMode: Text.NoWrap
                                elide: Text.ElideNone
                            }

                            Rectangle {
                                visible: root.selectedPackage !== null
                                width: parent.width
                                height: detailInfoColumn.implicitHeight + 32
                                radius: 18
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.frameBorder

                                Column {
                                    id: detailInfoColumn

                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.margins: 16
                                    spacing: 14

                                    Column {
                                        width: parent.width
                                        spacing: 10

                                        Rectangle {
                                            visible: root.pendingActionId.length > 0
                                            width: parent.width
                                            height: actionConfirmColumn.implicitHeight + 22
                                            radius: 14
                                            color: root.palette.cardBackground
                                            border.width: 1
                                            border.color: root.palette.warning

                                            Column {
                                                id: actionConfirmColumn

                                                anchors.fill: parent
                                                anchors.margins: 11
                                                spacing: 10

                                                Text {
                                                    width: parent.width
                                                    text: root.pendingActionLabel + " " + root.pendingActionPackageName + "?"
                                                    color: root.palette.primaryText
                                                    font.pixelSize: 13
                                                    font.bold: true
                                                }

                                                Text {
                                                    width: parent.width
                                                    wrapMode: Text.WordWrap
                                                    text: root.confirmationText()
                                                    color: root.palette.secondaryText
                                                    font.pixelSize: 12
                                                }

                                                Row {
                                                    spacing: 8

                                                    Rectangle {
                                                        width: 108
                                                        height: 30
                                                        radius: 10
                                                        color: root.palette.warning
                                                        border.width: 2
                                                        border.color: root.palette.warning

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "Confirm"
                                                            color: root.palette.primaryText
                                                            font.pixelSize: 12
                                                            font.bold: true
                                                        }

                                                        MouseArea {
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: root.runConfirmedAction()
                                                        }
                                                    }

                                                    Rectangle {
                                                        width: 88
                                                        height: 30
                                                        radius: 10
                                                        color: root.palette.panelBackground
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
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: root.clearPendingAction()
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Repeater {
                                            model: root.selectedPackage ? [
                                                {
                                                    "id": root.isInstalledPackage(root.selectedPackage) ? "reinstall" : "install",
                                                    "label": root.isInstalledPackage(root.selectedPackage) ? "Reinstall" : "Install",
                                                    "tone": "accent",
                                                    "available": true
                                                },
                                                {
                                                    "id": "upgrade",
                                                    "label": "Upgrade",
                                                    "tone": "warning",
                                                    "available": root.hasAvailableUpgrade(root.selectedPackage)
                                                },
                                                {
                                                    "id": "remove",
                                                    "label": "Remove",
                                                    "tone": "danger",
                                                    "available": root.isInstalledPackage(root.selectedPackage) && !root.isProtectedPackage(root.selectedPackage)
                                                }
                                            ] : []

                                            delegate: Rectangle {
                                                id: actionButton

                                                required property var modelData
                                                readonly property bool actionEnabled: modelData.available === true && !root.runningAction
                                                readonly property bool hovered: actionMouse.containsMouse
                                                readonly property color toneColor: modelData.tone === "danger"
                                                    ? root.palette.danger
                                                    : modelData.tone === "warning"
                                                        ? root.palette.warning
                                                        : root.palette.accent
                                                readonly property color fillColor: actionEnabled
                                                    ? Qt.alpha(toneColor, hovered ? 0.92 : 0.82)
                                                    : root.palette.panelBackground
                                                readonly property color outlineColor: actionEnabled
                                                    ? toneColor
                                                    : Qt.alpha(root.palette.frameBorder, 0.55)
                                                readonly property color labelColor: actionEnabled
                                                    ? root.palette.primaryText
                                                    : Qt.alpha(root.palette.mutedText, 0.7)

                                                width: parent.width
                                                height: 36
                                                radius: 12
                                                color: fillColor
                                                border.width: 2
                                                border.color: outlineColor

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: actionButton.modelData.label
                                                    color: actionButton.labelColor
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                }

                                                MouseArea {
                                                    id: actionMouse
                                                    anchors.fill: parent
                                                    enabled: actionButton.actionEnabled
                                                    hoverEnabled: actionButton.actionEnabled
                                                    cursorShape: actionButton.actionEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                                                    onClicked: root.requestAction(actionButton.modelData.id, actionButton.modelData.label, root.selectedPackage.name)
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: 1
                                        color: root.palette.frameBorder
                                        opacity: 0.55
                                    }

                                    Text {
                                        text: "Package Info"
                                        color: root.palette.secondaryText
                                        font.pixelSize: 14
                                        font.bold: true
                                    }

                                    Column {
                                        width: parent.width
                                        spacing: 6

                                        Repeater {
                                            model: root.selectedPackage ? [
                                                {
                                                    "label": "Version",
                                                    "value": root.versionText(root.selectedPackage)
                                                },
                                                {
                                                    "label": "Repository",
                                                    "value": root.selectedPackage.repo
                                                },
                                                {
                                                    "label": "License",
                                                    "value": root.formatLicense(root.selectedPackage.license)
                                                },
                                                {
                                                    "label": "Installed Size",
                                                    "value": root.selectedPackage.size
                                                }
                                            ] : []

                                            delegate: Row {
                                                id: detailRow

                                                required property var modelData
                                                width: parent.width
                                                spacing: 10

                                                Text {
                                                    width: 108
                                                    text: detailRow.modelData.label
                                                    color: root.palette.mutedText
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                }

                                                Text {
                                                    width: detailInfoColumn.width - 118
                                                    wrapMode: Text.WordWrap
                                                    text: detailRow.modelData.value
                                                    color: root.palette.primaryText
                                                    font.pixelSize: 13
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        text: "Homepage"
                                        color: root.palette.secondaryText
                                        font.pixelSize: 14
                                        font.bold: true
                                    }

                                    Text {
                                        width: parent.width
                                        wrapMode: Text.WrapAnywhere
                                        text: root.selectedPackage ? root.selectedPackage.website : ""
                                        color: root.palette.accentStrong
                                        font.pixelSize: 13
                                    }

                                    Column {
                                        width: parent.width
                                        spacing: 8

                                        Text {
                                            text: "Dependencies"
                                            color: root.palette.secondaryText
                                            font.pixelSize: 14
                                            font.bold: true
                                        }

                                        Flow {
                                            width: parent.width
                                            spacing: 8

                                            Repeater {
                                                model: root.selectedPackage ? root.selectedPackage.dependencies : []

                                                delegate: Rectangle {
                                                    id: dependencyChip

                                                    required property var modelData

                                                    height: 28
                                                    radius: 14
                                                    color: dependencyChip.modelData.installed
                                                        ? Qt.alpha(root.palette.success, 0.18)
                                                        : root.palette.cardBackground
                                                    border.width: 1
                                                    border.color: dependencyChip.modelData.installed
                                                        ? root.palette.success
                                                        : root.palette.frameBorder

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: dependencyChip.modelData.name
                                                        color: dependencyChip.modelData.installed
                                                            ? root.palette.success
                                                            : root.palette.primaryText
                                                        font.pixelSize: 12
                                                    }

                                                    width: textMetrics.width + 24

                                                    TextMetrics {
                                                        id: textMetrics
                                                        text: dependencyChip.modelData.name
                                                        font.pixelSize: 12
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Item {
                                visible: root.selectedPackage !== null
                                width: parent.width
                                height: 16
                            }
                        }

                        Rectangle {
                            visible: detailFlickable.contentHeight > detailFlickable.height
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            width: 6
                            radius: 3
                            color: root.palette.frameBorder
                            opacity: 0.32

                            Rectangle {
                                width: parent.width
                                radius: 3
                                color: root.palette.accent
                                opacity: 0.78
                                height: Math.max(36, parent.height * (detailFlickable.height / Math.max(detailFlickable.contentHeight, 1)))
                                y: (parent.height - height) * (detailFlickable.contentY / Math.max(detailFlickable.contentHeight - detailFlickable.height, 1))
                            }
                        }
                    }
                }
            }
        }
    }
}
