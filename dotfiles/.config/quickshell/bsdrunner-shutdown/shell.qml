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
    readonly property string action: Quickshell.env("BSDRUNNER_POWER_ACTION") === "shutdown"
        ? "shutdown" : "reboot"
    readonly property string actionNoun: action === "reboot" ? "restart" : "power off"
    readonly property string actionTitle: action === "reboot" ? "Restart BSDRunner" : "Power off BSDRunner"
    property var apps: []
    property bool snapshotBusy: false
    property bool commandBusy: false
    property bool committing: false
    property bool forceConfirmation: false
    property int emptySnapshots: 0
    property string commandMode: ""
    property string snapshotText: ""
    property string snapshotError: ""
    property int snapshotExitCode: 0
    property bool snapshotExited: false
    property bool snapshotOutFinished: false
    property bool snapshotErrFinished: false
    property string commandError: ""

    function backendCommand(mode) {
        return [
            "sh",
            Quickshell.env("BSDRUNNER_POWER_BACKEND").length > 0
                ? Quickshell.env("BSDRUNNER_POWER_BACKEND")
                : themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-shutdown-backend.sh",
            mode,
            action
        ]
    }

    function refresh() {
        if (snapshotBusy || commandBusy || committing)
            return
        snapshotText = ""
        snapshotError = ""
        snapshotExitCode = 0
        snapshotExited = false
        snapshotOutFinished = false
        snapshotErrFinished = false
        snapshotBusy = true
        snapshotProcess.running = true
    }

    function finishSnapshot() {
        if (!snapshotExited || !snapshotOutFinished || !snapshotErrFinished)
            return

        snapshotBusy = false
        if (snapshotExitCode !== 0) {
            commandError = snapshotError.trim().length > 0
                ? snapshotError.trim() : "Could not inspect the open applications."
            return
        }

        try {
            var payload = JSON.parse(snapshotText)
            if (!payload || !payload.ok)
                throw new Error("Invalid snapshot")
            apps = payload.apps || []
            commandError = ""
            if (apps.length === 0) {
                emptySnapshots += 1
                if (emptySnapshots >= 2 && !committing)
                    commitDelay.restart()
            } else {
                emptySnapshots = 0
                commitDelay.stop()
            }
        } catch (error) {
            commandError = "Could not read the open-application list."
        }
    }

    function runCommand(mode) {
        if (commandBusy || committing)
            return
        commandMode = mode
        commandError = ""
        commandBusy = true
        if (mode === "commit")
            committing = true
        commandProcess.command = backendCommand(mode)
        commandProcess.running = true
    }

    function forceClose() {
        if (!forceConfirmation) {
            forceConfirmation = true
            forceReset.restart()
            return
        }
        forceConfirmation = false
        runCommand("force")
    }

    function appName(app) {
        var value = (app.class || "Application").replace(/[-_.]+/g, " ")
        return value.replace(/\b\w/g, function(letter) { return letter.toUpperCase() })
    }

    Timer {
        interval: 900
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Timer {
        id: commitDelay
        interval: 450
        repeat: false
        onTriggered: root.runCommand("commit")
    }

    Timer {
        id: forceReset
        interval: 4500
        repeat: false
        onTriggered: root.forceConfirmation = false
    }

    Component.onCompleted: refresh()

    Process {
        id: snapshotProcess
        property var controller: root
        command: root.backendCommand("snapshot")

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                snapshotProcess.controller.snapshotText = text
                snapshotProcess.controller.snapshotOutFinished = true
                snapshotProcess.controller.finishSnapshot()
            }
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                snapshotProcess.controller.snapshotError = text
                snapshotProcess.controller.snapshotErrFinished = true
                snapshotProcess.controller.finishSnapshot()
            }
        }
        onExited: function(exitCode, exitStatus) {
            snapshotProcess.controller.snapshotExitCode = exitCode
            snapshotProcess.controller.snapshotExited = true
            snapshotProcess.controller.finishSnapshot()
        }
    }

    Process {
        id: commandProcess
        property var controller: root

        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: commandProcess.controller.commandError = text.trim()
        }
        onExited: function(exitCode, exitStatus) {
            var mode = commandProcess.controller.commandMode
            commandProcess.controller.commandBusy = false
            if (exitCode !== 0) {
                commandProcess.controller.committing = false
                if (commandProcess.controller.commandError.length === 0)
                    commandProcess.controller.commandError = "The " + mode + " step failed."
                return
            }
            if (mode !== "commit")
                commandProcess.controller.refresh()
        }
    }

    Connections {
        target: Quickshell
        function onLastWindowClosed() { Qt.quit() }
    }

    FloatingWindow {
        id: window

        visible: true
        title: "BSDRunner — " + root.actionTitle
        minimumSize: Qt.size(570, 540)
        maximumSize: Qt.size(570, 540)
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 24
            color: root.palette.frameBackground
            border.width: 2
            border.color: root.palette.frameBorder

            Rectangle {
                anchors.fill: parent
                anchors.margins: 12
                radius: 19
                color: root.palette.panelBackground
                border.width: 1
                border.color: root.palette.panelBorder

                Column {
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 14

                    Row {
                        width: parent.width
                        height: 68
                        spacing: 14

                        Rectangle {
                            width: 58
                            height: 58
                            radius: 18
                            color: Qt.alpha(root.action === "reboot" ? root.palette.accent : root.palette.danger, 0.18)
                            border.width: 1
                            border.color: root.action === "reboot" ? root.palette.accent : root.palette.danger

                            Text {
                                anchors.centerIn: parent
                                text: root.action === "reboot" ? "R" : "P"
                                color: root.action === "reboot" ? root.palette.accent : root.palette.danger
                                font.pixelSize: 25
                                font.bold: true
                            }
                        }

                        Column {
                            width: parent.width - 72
                            spacing: 4

                            Text {
                                text: root.actionTitle
                                color: root.palette.primaryText
                                font.pixelSize: 24
                                font.bold: true
                            }
                            Text {
                                text: root.palette.name + " session handoff"
                                color: root.palette.mutedText
                                font.pixelSize: 12
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 86
                        radius: 15
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.apps.length > 0 ? root.palette.warning : root.palette.success

                        Row {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 13

                            Rectangle {
                                width: 48
                                height: 48
                                radius: 24
                                color: Qt.alpha(root.apps.length > 0 ? root.palette.warning : root.palette.success, 0.16)

                                Text {
                                    anchors.centerIn: parent
                                    text: root.committing ? "…" : root.apps.length > 0 ? String(root.apps.length) : "✓"
                                    color: root.apps.length > 0 ? root.palette.warning : root.palette.success
                                    font.pixelSize: 18
                                    font.bold: true
                                }
                            }

                            Column {
                                width: parent.width - 61
                                spacing: 5

                                Text {
                                    width: parent.width
                                    text: root.committing
                                        ? "Finishing session cleanup"
                                        : root.apps.length > 0
                                            ? "Waiting for " + root.apps.length + (root.apps.length === 1 ? " application" : " applications")
                                            : "Applications are closed"
                                    color: root.palette.primaryText
                                    font.pixelSize: 15
                                    font.bold: true
                                }
                                Text {
                                    width: parent.width
                                    text: root.apps.length > 0
                                        ? "Check the desktop for save or confirmation dialogs. This window will not block them."
                                        : "BSDRunner will " + root.actionNoun + " when background cleanup finishes."
                                    color: root.palette.mutedText
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }

                    Text {
                        text: root.apps.length > 0 ? "OPEN APPLICATIONS" : "SESSION STATUS"
                        color: root.palette.accent
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1.2
                    }

                    Rectangle {
                        width: parent.width
                        height: 220
                        radius: 15
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.frameBorder

                        ListView {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 7
                            clip: true
                            model: root.apps
                            visible: root.apps.length > 0

                            delegate: Rectangle {
                                id: appRow
                                required property var modelData
                                width: ListView.view.width
                                height: 58
                                radius: 11
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.panelBorder

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: 9
                                    spacing: 11

                                    Rectangle {
                                        width: 38
                                        height: 38
                                        radius: 10
                                        color: Qt.alpha(root.palette.accent, 0.16)

                                        Text {
                                            anchors.centerIn: parent
                                            text: root.appName(appRow.modelData).charAt(0)
                                            color: root.palette.accent
                                            font.pixelSize: 16
                                            font.bold: true
                                        }
                                    }

                                    Column {
                                        width: parent.width - 49
                                        spacing: 2
                                        Text {
                                            width: parent.width
                                            text: root.appName(appRow.modelData)
                                            color: root.palette.primaryText
                                            font.pixelSize: 13
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            width: parent.width
                                            text: appRow.modelData.title || "Untitled window"
                                            color: root.palette.mutedText
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            visible: root.apps.length === 0

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.commandError.length > 0 ? "!" : "✓"
                                color: root.commandError.length > 0 ? root.palette.danger : root.palette.success
                                font.pixelSize: 34
                                font.bold: true
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 410
                                horizontalAlignment: Text.AlignHCenter
                                text: root.commandError.length > 0
                                    ? root.commandError : "No interactive applications remain."
                                color: root.commandError.length > 0 ? root.palette.danger : root.palette.mutedText
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        height: 46
                        spacing: 9

                        Rectangle {
                            id: cancelButton
                            width: 108
                            height: parent.height
                            radius: 12
                            color: cancelArea.containsMouse ? root.palette.cardHover : root.palette.cardBackground
                            border.width: 1
                            border.color: root.palette.frameBorder
                            opacity: root.committing ? 0.45 : 1

                            Text {
                                anchors.centerIn: parent
                                text: "Cancel"
                                color: root.palette.primaryText
                                font.pixelSize: 12
                                font.bold: true
                            }
                            MouseArea {
                                id: cancelArea
                                anchors.fill: parent
                                enabled: !root.committing
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: Qt.quit()
                            }
                        }

                        Rectangle {
                            id: retryButton
                            width: 108
                            height: parent.height
                            radius: 12
                            color: retryArea.containsMouse ? root.palette.cardHover : root.palette.cardBackground
                            border.width: 1
                            border.color: root.palette.accent
                            opacity: root.apps.length > 0 && !root.commandBusy ? 1 : 0.45

                            Text {
                                anchors.centerIn: parent
                                text: "Ask again"
                                color: root.palette.accent
                                font.pixelSize: 12
                                font.bold: true
                            }
                            MouseArea {
                                id: retryArea
                                anchors.fill: parent
                                enabled: root.apps.length > 0 && !root.commandBusy
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.runCommand("begin")
                            }
                        }

                        Rectangle {
                            id: forceButton
                            width: parent.width - cancelButton.width - retryButton.width - parent.spacing * 2
                            height: parent.height
                            radius: 12
                            color: forceArea.containsMouse
                                ? root.palette.danger : Qt.alpha(root.palette.danger, 0.18)
                            border.width: 1
                            border.color: root.palette.danger
                            opacity: root.apps.length > 0 && !root.commandBusy ? 1 : 0.45

                            Text {
                                anchors.centerIn: parent
                                text: root.forceConfirmation
                                    ? "Click again to discard work"
                                    : "Force close & " + root.actionNoun
                                color: forceArea.containsMouse ? root.palette.frameBackground : root.palette.danger
                                font.pixelSize: 11
                                font.bold: true
                            }
                            MouseArea {
                                id: forceArea
                                anchors.fill: parent
                                enabled: root.apps.length > 0 && !root.commandBusy
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.forceClose()
                            }
                        }
                    }
                }
            }
        }
    }
}
