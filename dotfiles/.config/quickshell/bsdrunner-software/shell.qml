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
    property string selectedPackageName: ""
    property string statusMessage: "Loading package metadata from pkg..."
    property string statusTone: "info"
    property string generatedAt: ""
    property bool loadingPackages: false
    property var packageData: []
    property int snapshotExitCode: 0
    property string snapshotStderrText: ""
    property bool snapshotExited: false
    property bool snapshotStdoutFinished: false
    property bool snapshotStderrFinished: false
    readonly property var visiblePackages: filterPackages(currentView, searchQuery)
    readonly property var selectedPackage: findPackage(selectedPackageName)

    function normalize(value) {
        return (value || "").toLowerCase()
    }

    function matchesView(pkg, view) {
        if (view === "installed")
            return pkg.installed
        if (view === "updates")
            return pkg.update_available
        return true
    }

    function filterPackages(view, query) {
        var results = []
        var needle = normalize(query)

        for (var i = 0; i < packageData.length; i += 1) {
            var pkg = packageData[i]
            if (!matchesView(pkg, view))
                continue

            if (needle.length > 0) {
                var haystack = normalize(pkg.name + " " + pkg.comment + " " + pkg.category)
                if (haystack.indexOf(needle) === -1)
                    continue
            }

            results.push(pkg)
        }

        return results
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
            return "Installed"
        case "updates":
            return "Updates"
        default:
            return "Browse"
        }
    }

    function viewSubtitle() {
        switch (currentView) {
        case "installed":
            return "Inspect the software that is already part of this BSDRunner machine."
        case "updates":
            return "Review the packages that would be refreshed in the next maintenance pass."
        default:
            return "Browse live package metadata from pkg and inspect what is available for this BSDRunner machine."
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
        var count = 0
        for (var i = 0; i < packageData.length; i += 1) {
            if (packageData[i].update_available)
                count += 1
        }
        return count
    }

    function triggerMockAction(action, pkgName) {
        var suffix = pkgName ? " for " + pkgName : ""
        statusTone = "warning"
        statusMessage = "Read-only mode: " + action + suffix + " is not wired to mdo-backed actions yet."
    }

    function versionText(pkg) {
        if (!pkg)
            return ""
        if (pkg.update_available && pkg.installed_version && pkg.installed_version !== pkg.version)
            return pkg.installed_version + " -> " + pkg.version
        if (pkg.installed && pkg.installed_version)
            return pkg.installed_version
        return pkg.version || ""
    }

    function refreshPackages() {
        if (snapshotProcess.running)
            return

        loadingPackages = true
        statusTone = "info"
        statusMessage = "Loading package metadata from pkg..."
        snapshotExitCode = 0
        snapshotStderrText = ""
        snapshotExited = false
        snapshotStdoutFinished = false
        snapshotStderrFinished = false
        snapshotProcess.running = true
    }

    function maybeFinalizeSnapshot() {
        if (!snapshotExited || !snapshotStdoutFinished || !snapshotStderrFinished)
            return

        root.applySnapshot(snapshotStdout.text, snapshotExitCode, snapshotStderrText)
    }

    function applySnapshot(text, exitCode, stderrText) {
        var payload = null

        if (!text || text.trim().length === 0) {
            statusTone = "error"
            statusMessage = stderrText && stderrText.trim().length > 0
                ? stderrText.trim()
                : "The pkg backend returned no data."
            packageData = []
            generatedAt = ""
            loadingPackages = false
            return
        }

        try {
            payload = JSON.parse(text)
        } catch (error) {
            statusTone = "error"
            statusMessage = "The pkg backend returned invalid JSON."
            packageData = []
            generatedAt = ""
            loadingPackages = false
            return
        }

        if (exitCode !== 0 || !payload.ok) {
            statusTone = "error"
            statusMessage = payload.message || stderrText || "Unable to load pkg metadata."
            packageData = []
            generatedAt = ""
            loadingPackages = false
            return
        }

        packageData = payload.packages || []
        generatedAt = payload.generated_at || ""
        statusTone = "info"
        statusMessage = payload.message || "Loaded package metadata from pkg."
        loadingPackages = false
    }

    onVisiblePackagesChanged: {
        if (visiblePackages.length === 0) {
            selectedPackageName = ""
        } else if (!packageInList(selectedPackageName, visiblePackages)) {
            selectedPackageName = visiblePackages[0].name
        }
    }

    Component.onCompleted: refreshPackages()

    Process {
        id: snapshotProcess

        command: ["sh", themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-software-backend.sh", "snapshot"]
        stdout: StdioCollector {
            id: snapshotStdout
            waitForEnd: true

            onStreamFinished: {
                root.snapshotStdoutFinished = true
                root.maybeFinalizeSnapshot()
            }
        }
        stderr: StdioCollector {
            id: snapshotStderr
            waitForEnd: true

            onStreamFinished: {
                root.snapshotStderrFinished = true
                root.snapshotStderrText = snapshotStderr.text
                root.maybeFinalizeSnapshot()
            }
        }

        onExited: function(exitCode, exitStatus) {
            root.snapshotExitCode = exitCode
            root.snapshotStderrText = snapshotStderr.text
            root.snapshotExited = true
            root.maybeFinalizeSnapshot()
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
        minimumSize: Qt.size(1160, 680)
        maximumSize: Qt.size(1160, 680)
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 28
            color: root.palette.frameBackground
            border.width: 2
            border.color: root.palette.frameBorder

            Rectangle {
                anchors.fill: parent
                anchors.margins: 18
                radius: 22
                color: root.palette.panelBackground
                border.width: 1
                border.color: root.palette.panelBorder

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 126
                    radius: 22
                    color: root.palette.cardBackground
                    opacity: 0.82

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 220
                        radius: 22
                        color: root.palette.accent
                        opacity: 0.12
                    }
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 4
                    radius: 2
                    color: root.palette.accent
                    opacity: 0.95
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 26
                    spacing: 18

                    Rectangle {
                        width: 216
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        radius: 20
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.panelBorder

                        Column {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 20

                            Column {
                                spacing: 8

                                Text {
                                    text: root.palette.eyebrow
                                    color: root.palette.accent
                                    font.pixelSize: 17
                                    font.bold: true
                                }

                                Text {
                                    text: "Software"
                                    color: root.palette.primaryText
                                    font.pixelSize: 34
                                    font.bold: true
                                }

                                Text {
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    text: "A themed FreeBSD package surface designed for BSDRunner."
                                    color: root.palette.secondaryText
                                    font.pixelSize: 14
                                }
                            }

                            Column {
                                spacing: 10

                                Repeater {
                                    model: [
                                        {
                                            "id": "browse",
                                            "label": "Browse",
                                            "count": root.packageData.length,
                                            "accent": root.palette.accent
                                        },
                                        {
                                            "id": "installed",
                                            "label": "Installed",
                                            "count": root.installedCount(),
                                            "accent": root.palette.success
                                        },
                                        {
                                            "id": "updates",
                                            "label": "Updates",
                                            "count": root.updateCount(),
                                            "accent": root.palette.warning
                                        }
                                    ]

                                    delegate: Rectangle {
                                        id: navCard

                                        required property var modelData
                                        readonly property bool active: root.currentView === modelData.id

                                        width: 176
                                        height: 66
                                        radius: 16
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
                                                    font.pixelSize: 14
                                                    font.bold: true
                                                }
                                            }

                                            Column {
                                                anchors.verticalCenter: parent.verticalCenter
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
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor

                                            onEntered: parent.color = root.palette.cardHover
                                            onExited: parent.color = parent.active ? root.palette.cardHover : root.palette.panelBackground
                                            onClicked: root.currentView = parent.modelData.id
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 156
                                radius: 18
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.frameBorder

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 8

                                    Text {
                                        text: "Current Theme"
                                        color: root.palette.mutedText
                                        font.pixelSize: 12
                                        font.bold: true
                                    }

                                    Text {
                                        text: root.palette.name
                                        color: root.palette.accentStrong
                                        font.pixelSize: 24
                                        font.bold: true
                                    }

                                    Text {
                                        width: parent.width
                                        wrapMode: Text.WordWrap
                                        text: root.loadingPackages
                                            ? "Refreshing package metadata from pkg right now."
                                            : root.generatedAt.length > 0
                                                ? "Last pkg snapshot: " + root.generatedAt
                                                : "Package data will appear here after the first successful pkg snapshot."
                                        color: root.palette.secondaryText
                                        font.pixelSize: 13
                                    }

                                    Rectangle {
                                        width: 144
                                        height: 34
                                        radius: 12
                                        color: root.palette.accent
                                        opacity: root.loadingPackages ? 0.10 : 0.18
                                        border.width: 1
                                        border.color: root.palette.accent

                                        Text {
                                            anchors.centerIn: parent
                                            text: root.loadingPackages ? "Refreshing" : "Refresh pkg"
                                            color: root.palette.accentStrong
                                            font.pixelSize: 12
                                            font.bold: true
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: !root.loadingPackages
                                            hoverEnabled: true
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                                            onEntered: parent.opacity = 0.26
                                            onExited: parent.opacity = root.loadingPackages ? 0.10 : 0.18
                                            onClicked: root.refreshPackages()
                                        }
                                    }
                                }
                            }
                        }
                    }

                        Column {
                            id: centerColumn

                            width: 520
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            spacing: 16

                            Column {
                                id: centerHeader

                                spacing: 10

                            Text {
                                text: root.viewTitle()
                                color: root.palette.primaryText
                                font.pixelSize: 34
                                font.bold: true
                            }

                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: root.viewSubtitle()
                                color: root.palette.secondaryText
                                font.pixelSize: 15
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

                                onTextChanged: root.searchQuery = text

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: parent.text.length === 0
                                    text: "Search packages, comments, or categories"
                                    color: root.palette.mutedText
                                    font.pixelSize: 16
                                }
                            }
                        }

                        Rectangle {
                            id: statusBanner

                            width: parent.width
                            height: 68
                            radius: 16
                            color: root.statusTone === "warning"
                                ? root.palette.warning
                                : root.statusTone === "error"
                                    ? root.palette.danger
                                    : root.palette.accent
                            opacity: 0.18
                            border.width: 1
                            border.color: root.statusTone === "warning"
                                ? root.palette.warning
                                : root.statusTone === "error"
                                    ? root.palette.danger
                                    : root.palette.accent

                            Text {
                                anchors.fill: parent
                                anchors.margins: 16
                                verticalAlignment: Text.AlignVCenter
                                wrapMode: Text.WordWrap
                                text: root.statusMessage
                                color: root.palette.primaryText
                                font.pixelSize: 14
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: centerColumn.height - centerHeader.height - searchBarFrame.height - statusBanner.height - (centerColumn.spacing * 3)
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
                                    anchors.fill: parent
                                    contentWidth: width
                                    contentHeight: packageColumn.height
                                    clip: true
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

                                                width: packageColumn.width
                                                height: 102
                                                radius: 18
                                                color: active ? root.palette.cardHover : root.palette.panelBackground
                                                border.width: 1
                                                border.color: active ? root.palette.accent : root.palette.frameBorder

                                                Column {
                                                    anchors.fill: parent
                                                    anchors.margins: 16
                                                    spacing: 8

                                                    Row {
                                                        width: parent.width
                                                        spacing: 10

                                                        Text {
                                                            text: packageCard.pkg.name
                                                            color: root.palette.primaryText
                                                            font.pixelSize: 20
                                                            font.bold: true
                                                        }

                                                        Rectangle {
                                                            width: 80
                                                            height: 24
                                                            radius: 12
                                                            color: packageCard.pkg.installed ? root.palette.success : root.palette.accent
                                                            opacity: 0.16

                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: packageCard.pkg.installed ? "Installed" : "Available"
                                                                color: packageCard.pkg.installed ? root.palette.success : root.palette.accentStrong
                                                                font.pixelSize: 12
                                                                font.bold: true
                                                            }
                                                        }

                                                        Rectangle {
                                                            visible: packageCard.pkg.update_available
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

                                                    Row {
                                                        spacing: 14

                                                        Text {
                                                            text: packageCard.pkg.category
                                                            color: root.palette.accent
                                                            font.pixelSize: 12
                                                            font.bold: true
                                                        }

                                                        Text {
                                                            text: root.versionText(packageCard.pkg)
                                                            color: root.palette.mutedText
                                                            font.pixelSize: 12
                                                        }

                                                        Text {
                                                            text: packageCard.pkg.repo
                                                            color: root.palette.mutedText
                                                            font.pixelSize: 12
                                                        }
                                                    }
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor

                                                    onEntered: parent.color = root.palette.cardHover
                                                    onExited: parent.color = parent.active ? root.palette.cardHover : root.palette.panelBackground
                                                    onClicked: root.selectedPackageName = parent.modelData.name
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 336
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        radius: 20
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.panelBorder

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 20
                            contentWidth: width
                            contentHeight: detailColumn.height
                            clip: true

                            Column {
                                id: detailColumn

                                width: parent.width
                                spacing: 16

                                Text {
                                    text: root.selectedPackage ? root.selectedPackage.name : "No package selected"
                                    color: root.palette.primaryText
                                    font.pixelSize: 30
                                    font.bold: true
                                }

                                Text {
                                    visible: root.selectedPackage !== null
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    text: root.selectedPackage ? root.selectedPackage.description : ""
                                    color: root.palette.secondaryText
                                    font.pixelSize: 14
                                }

                                Rectangle {
                                    visible: root.selectedPackage !== null
                                    width: parent.width
                                    height: 170
                                    radius: 18
                                    color: root.palette.panelBackground
                                    border.width: 1
                                    border.color: root.palette.frameBorder

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 16
                                        spacing: 10

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
                                                    "value": root.selectedPackage.license
                                                },
                                                {
                                                    "label": "Installed Size",
                                                    "value": root.selectedPackage.size
                                                }
                                            ] : []

                                                delegate: Row {
                                                    id: detailRow

                                                    required property var modelData
                                                    spacing: 12

                                                    Text {
                                                        width: 108
                                                        text: detailRow.modelData.label
                                                        color: root.palette.mutedText
                                                        font.pixelSize: 12
                                                        font.bold: true
                                                }

                                                    Text {
                                                        width: 180
                                                        wrapMode: Text.WordWrap
                                                        text: detailRow.modelData.value
                                                        color: root.palette.primaryText
                                                        font.pixelSize: 13
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Column {
                                    visible: root.selectedPackage !== null
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

                                                required property string modelData

                                                height: 28
                                                radius: 14
                                                color: root.palette.panelBackground
                                                border.width: 1
                                                border.color: root.palette.frameBorder

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: dependencyChip.modelData
                                                    color: root.palette.primaryText
                                                    font.pixelSize: 12
                                                }

                                                width: textMetrics.width + 24

                                                TextMetrics {
                                                    id: textMetrics
                                                    text: dependencyChip.modelData
                                                    font.pixelSize: 12
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    visible: root.selectedPackage !== null
                                    width: parent.width
                                    height: 112
                                    radius: 18
                                    color: root.palette.panelBackground
                                    border.width: 1
                                    border.color: root.palette.frameBorder

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 16
                                        spacing: 10

                                        Text {
                                            text: "Actions"
                                            color: root.palette.secondaryText
                                            font.pixelSize: 14
                                            font.bold: true
                                        }

                                        Row {
                                            spacing: 10

                                            Repeater {
                                                model: root.selectedPackage ? [
                                                    {
                                                        "label": root.selectedPackage.installed ? "Reinstall" : "Install",
                                                        "tone": "accent"
                                                    },
                                                    {
                                                        "label": "Upgrade",
                                                        "tone": "warning"
                                                    },
                                                    {
                                                        "label": "Remove",
                                                        "tone": "danger"
                                                    }
                                                ] : []

                                                delegate: Rectangle {
                                                    id: actionButton

                                                    required property var modelData
                                                    readonly property color toneColor: modelData.tone === "danger"
                                                        ? root.palette.danger
                                                        : modelData.tone === "warning"
                                                            ? root.palette.warning
                                                            : root.palette.accent

                                                    width: 96
                                                    height: 36
                                                    radius: 12
                                                    color: toneColor
                                                    opacity: 0.16
                                                    border.width: 1
                                                    border.color: toneColor

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: actionButton.modelData.label
                                                        color: parent.toneColor
                                                        font.pixelSize: 12
                                                        font.bold: true
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor

                                                        onEntered: parent.opacity = 0.24
                                                        onExited: parent.opacity = 0.16
                                                        onClicked: root.triggerMockAction(actionButton.modelData.label.toLowerCase(), root.selectedPackage.name)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    visible: root.selectedPackage !== null
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    text: root.selectedPackage ? root.selectedPackage.website : ""
                                    color: root.palette.accentStrong
                                    font.pixelSize: 13
                                }
                            }
                        }
                    }
                }
            }
        }
    }
