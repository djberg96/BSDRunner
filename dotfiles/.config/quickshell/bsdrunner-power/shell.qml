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
    readonly property var timeoutOptions: [5, 10, 15, 30, 60]
    property bool lockEnabled: true
    property int timeoutMinutes: 15
    property bool hypridleInstalled: false
    property bool hyprlockInstalled: false
    property bool idleRunning: false
    property int pendingTimeoutMinutes: 15
    property string statusMessage: "Loading power settings..."
    property string statusTone: "info"
    property string snapshotStdoutText: ""
    property string snapshotStderrText: ""
    property int snapshotExitCode: 0
    property bool snapshotExited: false
    property bool snapshotStdoutFinished: false
    property bool snapshotStderrFinished: false

    function statusColor() {
        if (!hypridleInstalled || !hyprlockInstalled)
            return palette.danger
        if (!lockEnabled)
            return palette.warning
        if (!idleRunning)
            return palette.warning
        return palette.success
    }

    function refreshSettings() {
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

        if (snapshotExitCode !== 0) {
            statusTone = "error"
            statusMessage = snapshotStderrText.trim().length > 0
                ? snapshotStderrText.trim()
                : "Unable to load power settings."
            return
        }

        var payload = null
        try {
            payload = JSON.parse(snapshotStdoutText)
        } catch (error) {
            payload = null
        }

        if (!payload || !payload.ok) {
            statusTone = "error"
            statusMessage = payload && payload.message ? payload.message : "Power settings unavailable."
            return
        }

        lockEnabled = !!payload.enabled
        timeoutMinutes = payload.timeout_minutes || 15
        hypridleInstalled = !!payload.hypridle_installed
        hyprlockInstalled = !!payload.hyprlock_installed
        idleRunning = !!payload.idle_running
        statusMessage = payload.message || "Power settings loaded."
        statusTone = !hypridleInstalled || !hyprlockInstalled
            ? "error"
            : !lockEnabled || !idleRunning ? "warning" : "success"
    }

    function runSetting(action, value, optimisticMessage) {
        statusMessage = optimisticMessage
        statusTone = "info"
        Quickshell.execDetached([
            "sh",
            themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-power-backend.sh",
            action,
            String(value)
        ])
        refreshDelay.restart()
    }

    function setTimeoutMinutes(value) {
        var bounded = Math.max(1, Math.min(120, value))
        timeoutMinutes = bounded
        pendingTimeoutMinutes = bounded
        statusMessage = "Updating the automatic lock delay..."
        statusTone = "info"
        timeoutApplyDelay.restart()
    }

    function setLockEnabled(value) {
        lockEnabled = value
        runSetting("set-enabled", value ? "yes" : "no",
                   value ? "Starting automatic screen locking..." : "Stopping automatic screen locking...")
    }

    function lockNow() {
        statusMessage = "Locking this session..."
        statusTone = "info"
        Quickshell.execDetached([
            "sh",
            themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-lock.sh"
        ])
    }

    Timer {
        id: timeoutApplyDelay

        interval: 300
        repeat: false
        onTriggered: root.runSetting("set-timeout", root.pendingTimeoutMinutes,
                                     "Updating the automatic lock delay...")
    }

    Timer {
        id: refreshDelay

        interval: 700
        repeat: false
        onTriggered: root.refreshSettings()
    }

    Component.onCompleted: refreshSettings()

    Process {
        id: snapshotProcess
        property var controller: root

        command: [
            "sh",
            themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-power-backend.sh",
            "snapshot"
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
        title: "BSDRunner Power Settings"
        minimumSize: Qt.size(680, 590)
        maximumSize: Qt.size(680, 590)
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 22
            color: root.palette.frameBackground
            border.width: 2
            border.color: root.palette.frameBorder

            Rectangle {
                anchors.fill: parent
                anchors.margins: 14
                radius: 18
                color: root.palette.panelBackground
                border.width: 1
                border.color: root.palette.panelBorder

                Column {
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 16

                    Row {
                        width: parent.width
                        height: 58
                        spacing: 12

                        Column {
                            width: parent.width - closeButton.width - 12
                            spacing: 2

                            Text {
                                text: "Power Settings"
                                color: root.palette.primaryText
                                font.pixelSize: 26
                                font.bold: true
                            }

                            Text {
                                text: "Automatic session locking"
                                color: root.palette.mutedText
                                font.pixelSize: 12
                            }
                        }

                        Rectangle {
                            id: closeButton

                            width: 42
                            height: 42
                            radius: 12
                            color: closeMouse.containsMouse ? root.palette.cardHover : root.palette.cardBackground
                            border.width: 1
                            border.color: root.palette.frameBorder

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                color: root.palette.primaryText
                                font.pixelSize: 24
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
                        height: 88
                        radius: 14
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.statusColor()

                        Row {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 14

                            Rectangle {
                                width: 54
                                height: 54
                                radius: 27
                                color: Qt.alpha(root.statusColor(), 0.18)
                                border.width: 2
                                border.color: root.statusColor()

                                Text {
                                    anchors.centerIn: parent
                                    text: root.lockEnabled && root.idleRunning ? "ON" : "—"
                                    color: root.statusColor()
                                    font.pixelSize: 14
                                    font.bold: true
                                }
                            }

                            Column {
                                width: parent.width - 68
                                spacing: 5

                                Text {
                                    width: parent.width
                                    text: !root.hyprlockInstalled
                                        ? "hyprlock is not installed"
                                        : !root.hypridleInstalled
                                            ? "hypridle is not installed"
                                            : root.lockEnabled && root.idleRunning
                                                ? "Automatic locking is active"
                                                : root.lockEnabled
                                                    ? "Automatic locking needs attention"
                                                    : "Automatic locking is disabled"
                                    color: root.statusColor()
                                    font.pixelSize: 16
                                    font.bold: true
                                }

                                Text {
                                    width: parent.width
                                    text: root.statusMessage
                                    color: root.palette.mutedText
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 76
                        radius: 14
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.frameBorder

                        Row {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 12

                            Column {
                                width: parent.width - enableToggle.width - 12
                                spacing: 4

                                Text {
                                    text: "Lock this session automatically"
                                    color: root.palette.primaryText
                                    font.pixelSize: 15
                                    font.bold: true
                                }

                                Text {
                                    text: "Keeps applications open and requires your password to return."
                                    color: root.palette.mutedText
                                    font.pixelSize: 11
                                }
                            }

                            Rectangle {
                                id: enableToggle

                                width: 62
                                height: 32
                                radius: 16
                                color: root.lockEnabled ? root.palette.accent : root.palette.frameBorder
                                opacity: root.hypridleInstalled && root.hyprlockInstalled ? 1.0 : 0.5

                                Rectangle {
                                    width: 24
                                    height: 24
                                    radius: 12
                                    x: root.lockEnabled ? parent.width - width - 4 : 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: root.lockEnabled ? root.palette.frameBackground : root.palette.mutedText
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: root.hypridleInstalled && root.hyprlockInstalled
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: root.setLockEnabled(!root.lockEnabled)
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 164
                        radius: 14
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.frameBorder

                        Column {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 12

                            Row {
                                width: parent.width
                                height: 48
                                spacing: 10

                                Column {
                                    width: parent.width - timeoutStepper.width - 10
                                    spacing: 4

                                    Text {
                                        text: "Lock after inactivity"
                                        color: root.palette.primaryText
                                        font.pixelSize: 15
                                        font.bold: true
                                    }

                                    Text {
                                        text: "Videos and other idle-inhibiting apps can postpone the timer."
                                        color: root.palette.mutedText
                                        font.pixelSize: 11
                                    }
                                }

                                Row {
                                    id: timeoutStepper

                                    width: 196
                                    height: 42
                                    spacing: 6

                                    Repeater {
                                        model: [
                                            {"label": "−", "delta": -1},
                                            {"label": "+", "delta": 1}
                                        ]

                                        delegate: Rectangle {
                                            id: stepButton

                                            required property var modelData
                                            width: 42
                                            height: 42
                                            radius: 10
                                            color: stepMouse.containsMouse ? root.palette.cardHover : root.palette.panelBackground
                                            border.width: 1
                                            border.color: root.palette.frameBorder

                                            Text {
                                                anchors.centerIn: parent
                                                text: stepButton.modelData.label
                                                color: root.palette.primaryText
                                                font.pixelSize: 22
                                                font.bold: true
                                            }

                                            MouseArea {
                                                id: stepMouse

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.setTimeoutMinutes(root.timeoutMinutes + stepButton.modelData.delta)
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: 96
                                        height: 42
                                        radius: 10
                                        color: root.palette.panelBackground
                                        border.width: 1
                                        border.color: root.palette.accent

                                        Text {
                                            anchors.centerIn: parent
                                            text: root.timeoutMinutes + " min"
                                            color: root.palette.accent
                                            font.pixelSize: 15
                                            font.bold: true
                                        }
                                    }
                                }
                            }

                            Row {
                                id: presetRow

                                width: parent.width
                                height: 44
                                spacing: 8

                                Repeater {
                                    model: root.timeoutOptions

                                    delegate: Rectangle {
                                        id: presetButton

                                        required property int modelData
                                        readonly property bool selected: root.timeoutMinutes === modelData

                                        width: (presetRow.width - presetRow.spacing * (root.timeoutOptions.length - 1)) / root.timeoutOptions.length
                                        height: 42
                                        radius: 10
                                        color: selected ? root.palette.accent : (presetMouse.containsMouse ? root.palette.cardHover : root.palette.panelBackground)
                                        border.width: 1
                                        border.color: selected ? root.palette.accentStrong : root.palette.frameBorder

                                        Text {
                                            anchors.centerIn: parent
                                            text: presetButton.modelData + " min"
                                            color: presetButton.selected ? root.palette.frameBackground : root.palette.secondaryText
                                            font.pixelSize: 12
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: presetMouse

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.setTimeoutMinutes(presetButton.modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        height: 48
                        spacing: 12

                        Rectangle {
                            width: (parent.width - parent.spacing) / 2
                            height: 48
                            radius: 12
                            color: lockNowMouse.containsMouse ? root.palette.accentStrong : root.palette.accent
                            opacity: root.hyprlockInstalled ? 1.0 : 0.5

                            Text {
                                anchors.centerIn: parent
                                text: "Lock Now"
                                color: root.palette.frameBackground
                                font.pixelSize: 14
                                font.bold: true
                            }

                            MouseArea {
                                id: lockNowMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: root.hyprlockInstalled
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.lockNow()
                            }
                        }

                        Rectangle {
                            width: (parent.width - parent.spacing) / 2
                            height: 48
                            radius: 12
                            color: doneMouse.containsMouse ? root.palette.cardHover : root.palette.cardBackground
                            border.width: 1
                            border.color: root.palette.frameBorder

                            Text {
                                anchors.centerIn: parent
                                text: "Done"
                                color: root.palette.primaryText
                                font.pixelSize: 14
                                font.bold: true
                            }

                            MouseArea {
                                id: doneMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Qt.quit()
                            }
                        }
                    }
                }
            }
        }
    }
}
