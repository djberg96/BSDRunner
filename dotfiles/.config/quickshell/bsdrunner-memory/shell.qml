pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtCore
import QtQuick

ShellRoot {
    id: root

    function localPath(value) {
        var text = String(value || "")
        if (text.indexOf("file://") === 0)
            return decodeURIComponent(text.replace(/^file:\/+/, "/"))
        return text
    }

    readonly property string homeDir: localPath(StandardPaths.writableLocation(StandardPaths.HomeLocation))
    readonly property string activeTheme: {
        var text = themeFile.text().trim()
        return text.length > 0 ? text : "default"
    }
    readonly property string palettePath: homeDir + "/.config/bsdrunner/themes/" + activeTheme + "/palette.conf"
    property var processes: []
    property string statusMessage: "Loading process memory..."
    property string generatedAt: ""
    property string topTotalLabel: "--"
    property int largestRssMb: 1
    property string snapshotStdoutText: ""
    property string snapshotStderrText: ""
    property int snapshotExitCode: 0
    property bool snapshotExited: false
    property bool snapshotStdoutFinished: false
    property bool snapshotStderrFinished: false

    function paletteValue(key, fallback) {
        var lines = paletteFile.text().split("\n")
        for (var i = 0; i < lines.length; i += 1) {
            var line = lines[i].trim()
            if (line.indexOf(key + "=") === 0)
                return line.substring(key.length + 1).trim()
        }
        return fallback
    }

    readonly property color backgroundColor: paletteValue("background", "#0f1418")
    readonly property color surfaceColor: paletteValue("surface", "#1b2329")
    readonly property color textColor: paletteValue("text", "#d7e3ea")
    readonly property color accentColor: paletteValue("accent", "#8fd3ff")
    readonly property color accentStrongColor: paletteValue("accent_strong", "#dff6ff")
    readonly property color warningColor: paletteValue("warning", "#ffb86b")

    function refreshMemory() {
        snapshotStdoutText = ""
        snapshotStderrText = ""
        snapshotExitCode = 0
        snapshotExited = false
        snapshotStdoutFinished = false
        snapshotStderrFinished = false
        snapshotProcess.running = true
    }

    function barWidth(rssMb, maxWidth) {
        var value = Number(rssMb || 0)
        var largest = Math.max(1, largestRssMb)
        return Math.max(8, Math.round(maxWidth * (value / largest)))
    }

    function maybeFinalizeSnapshot() {
        if (!snapshotExited || !snapshotStdoutFinished || !snapshotStderrFinished)
            return

        var payload = null
        try {
            payload = JSON.parse(snapshotStdoutText || "{}")
        } catch (error) {
            payload = null
        }

        if (snapshotExitCode !== 0 || !payload || !payload.ok) {
            processes = []
            statusMessage = payload && payload.message
                ? payload.message
                : snapshotStderrText.trim().length > 0
                    ? snapshotStderrText.trim()
                    : "Unable to read process memory."
            generatedAt = ""
            topTotalLabel = "--"
            largestRssMb = 1
            return
        }

        processes = payload.processes || []
        statusMessage = payload.message || "Top memory consumers by command name."
        generatedAt = payload.generated_at || ""
        topTotalLabel = payload.top_total_label || "--"
        largestRssMb = 1

        for (var i = 0; i < processes.length; i += 1)
            largestRssMb = Math.max(largestRssMb, Number(processes[i].rss_mb || 0))
    }

    Timer {
        interval: 15000
        repeat: true
        running: true
        onTriggered: root.refreshMemory()
    }

    Component.onCompleted: refreshMemory()

    FileView {
        id: themeFile

        path: root.homeDir + "/.config/bsdrunner/current-theme"
        blockLoading: true
        watchChanges: true

        onFileChanged: this.reload()
    }

    FileView {
        id: paletteFile

        path: root.palettePath
        blockLoading: true
        watchChanges: true

        onFileChanged: this.reload()
        onPathChanged: this.reload()
    }

    Process {
        id: snapshotProcess
        property var controller: root

        command: [
            "sh",
            root.homeDir + "/.config/bsdrunner/scripts/bsdrunner-memory-backend.sh"
        ]

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

        onExited: function(exitCode, exitStatus) {
            snapshotProcess.controller.snapshotExitCode = exitCode
            snapshotProcess.controller.snapshotExited = true
            snapshotProcess.controller.maybeFinalizeSnapshot()
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
        title: "BSDRunner Memory"
        minimumSize: Qt.size(560, 430)
        maximumSize: Qt.size(560, 430)
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 22
            color: root.backgroundColor
            border.width: 2
            border.color: Qt.alpha(root.accentColor, 0.42)

            Rectangle {
                anchors.fill: parent
                anchors.margins: 14
                radius: 18
                color: root.surfaceColor
                border.width: 1
                border.color: Qt.alpha(root.accentColor, 0.30)

                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 14

                    Row {
                        width: parent.width
                        spacing: 12

                        Column {
                            width: parent.width - closeButton.width - 12
                            spacing: 4

                            Text {
                                text: "Memory"
                                color: root.accentColor
                                font.pixelSize: 15
                                font.bold: true
                            }

                            Text {
                                text: root.statusMessage
                                color: Qt.alpha(root.textColor, 0.72)
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        Rectangle {
                            id: closeButton

                            width: 34
                            height: 34
                            radius: 8
                            color: closeArea.containsMouse ? Qt.alpha(root.accentColor, 0.26) : Qt.alpha(root.backgroundColor, 0.55)
                            border.width: 1
                            border.color: Qt.alpha(root.accentColor, 0.36)

                            Text {
                                anchors.centerIn: parent
                                text: "X"
                                color: root.textColor
                                font.pixelSize: 14
                                font.bold: true
                            }

                            MouseArea {
                                id: closeArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Qt.quit()
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 58
                        radius: 14
                        color: Qt.alpha(root.backgroundColor, 0.58)
                        border.width: 1
                        border.color: Qt.alpha(root.accentColor, 0.24)

                        Row {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 18

                            Text {
                                text: "Top 8 RSS"
                                color: root.textColor
                                font.pixelSize: 18
                                font.bold: true
                                verticalAlignment: Text.AlignVCenter
                                height: parent.height
                            }

                            Text {
                                text: root.topTotalLabel
                                color: root.accentStrongColor
                                font.pixelSize: 18
                                font.bold: true
                                verticalAlignment: Text.AlignVCenter
                                height: parent.height
                            }

                            Text {
                                width: parent.width - 198
                                text: root.generatedAt.length > 0 ? "Updated " + root.generatedAt : ""
                                color: Qt.alpha(root.textColor, 0.58)
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignRight
                                verticalAlignment: Text.AlignVCenter
                                height: parent.height
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Flickable {
                        id: processFlickable

                        width: parent.width
                        height: parent.height - y
                        contentWidth: width
                        contentHeight: processColumn.height
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        interactive: contentHeight > height

                        Column {
                            id: processColumn

                            width: processFlickable.width - (processFlickable.contentHeight > processFlickable.height ? 12 : 0)
                            spacing: 8

                            Repeater {
                                model: root.processes

                                delegate: Rectangle {
                                    id: processRow

                                    required property var modelData

                                    width: parent.width
                                    height: 34
                                    radius: 10
                                    color: Qt.alpha(root.backgroundColor, 0.42)
                                    border.width: 1
                                    border.color: Qt.alpha(root.accentColor, 0.16)

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.leftMargin: 8
                                        width: root.barWidth(processRow.modelData.rss_mb, parent.width - 16)
                                        height: parent.height - 12
                                        radius: 7
                                        color: Qt.alpha(root.accentColor, 0.28)
                                    }

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 10

                                        Text {
                                            width: 176
                                            text: processRow.modelData.name
                                            color: root.textColor
                                            font.pixelSize: 13
                                            font.bold: true
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        Text {
                                            width: 88
                                            text: processRow.modelData.rss_label
                                            color: root.accentStrongColor
                                            font.pixelSize: 13
                                            font.bold: true
                                            horizontalAlignment: Text.AlignRight
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        Text {
                                            width: 72
                                            text: processRow.modelData.count + " proc"
                                            color: Qt.alpha(root.textColor, 0.70)
                                            font.pixelSize: 12
                                            horizontalAlignment: Text.AlignRight
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        Text {
                                            width: parent.width - 366
                                            text: "CPU " + processRow.modelData.cpu + "%"
                                            color: Qt.alpha(root.textColor, 0.60)
                                            font.pixelSize: 12
                                            horizontalAlignment: Text.AlignRight
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            visible: processFlickable.contentHeight > processFlickable.height
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            width: 5
                            radius: 3
                            color: Qt.alpha(root.accentColor, 0.16)

                            Rectangle {
                                width: parent.width
                                radius: 3
                                color: Qt.alpha(root.accentColor, 0.78)
                                height: Math.max(28, parent.height * (processFlickable.height / Math.max(processFlickable.contentHeight, 1)))
                                y: (parent.height - height) * (processFlickable.contentY / Math.max(processFlickable.contentHeight - processFlickable.height, 1))
                            }
                        }
                    }
                }
            }
        }
    }
}
