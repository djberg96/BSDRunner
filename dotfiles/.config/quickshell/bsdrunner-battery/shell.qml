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
    readonly property var thresholdOptions: [3, 5, 7, 10, 15]
    property string batteryState: "unknown"
    property string batteryStateLabel: "Loading..."
    property string batteryCapacity: "--"
    property string batteryRemaining: ""
    property int alertThreshold: 5
    property bool criticalAlert: false
    property bool batteryAvailable: false
    property string statusMessage: "Loading battery information..."
    property string statusTone: "info"
    property string snapshotStdoutText: ""
    property string snapshotStderrText: ""
    property int snapshotExitCode: 0
    property bool snapshotExited: false
    property bool snapshotStdoutFinished: false
    property bool snapshotStderrFinished: false

    function statusColor() {
        if (!batteryAvailable)
            return palette.mutedText
        if (criticalAlert)
            return palette.danger
        if (batteryState === "charging" || batteryState === "high" || batteryState === "full")
            return palette.success
        return palette.warning
    }

    function thresholdButtonColor(value, hovered) {
        if (alertThreshold === value)
            return hovered ? palette.accentStrong : palette.accent
        return hovered ? palette.cardHover : palette.cardBackground
    }

    function thresholdTextColor(value) {
        if (alertThreshold === value)
            return palette.frameBackground
        return palette.primaryText
    }

    function refreshBattery() {
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
            batteryAvailable = false
            statusTone = "error"
            statusMessage = snapshotStderrText.trim().length > 0
                ? snapshotStderrText.trim()
                : "Unable to refresh battery information."
            return
        }

        var payload = null
        try {
            payload = JSON.parse(snapshotStdoutText)
        } catch (error) {
            payload = null
        }

        if (!payload || !payload.ok) {
            batteryAvailable = false
            statusTone = "error"
            statusMessage = payload && payload.message ? payload.message : "Battery information unavailable."
            if (payload && payload.threshold)
                alertThreshold = payload.threshold
            return
        }

        batteryAvailable = !!payload.available
        batteryState = payload.state || "unknown"
        batteryStateLabel = payload.state_label || "Unknown"
        batteryCapacity = payload.capacity || "--"
        batteryRemaining = payload.remaining || ""
        alertThreshold = payload.threshold || 5
        criticalAlert = !!payload.critical
        statusTone = criticalAlert ? "critical" : "info"
        statusMessage = criticalAlert
            ? "Battery is at or below the configured alert threshold."
            : "Choose when BSDRunner should warn you."
    }

    function applyThreshold(value) {
        alertThreshold = value
        criticalAlert = batteryAvailable && batteryState === "discharging" && parseInt(batteryCapacity) <= value
        statusTone = "success"
        statusMessage = "Battery alert threshold set to " + value + "%."

        Quickshell.execDetached([
            "sh",
            themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-battery-backend.sh",
            "set-threshold",
            String(value)
        ])

        refreshDelay.restart()
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.refreshBattery()
    }

    Timer {
        id: refreshDelay

        interval: 250
        repeat: false
        onTriggered: root.refreshBattery()
    }

    Component.onCompleted: refreshBattery()

    Process {
        id: snapshotProcess
        property var controller: root

        command: [
            "sh",
            themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-battery-backend.sh",
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
        title: "BSDRunner Battery"
        minimumSize: Qt.size(420, 368)
        maximumSize: Qt.size(420, 368)
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
                    anchors.margins: 20
                    spacing: 18

                    Row {
                        width: parent.width
                        spacing: 12

                        Column {
                            width: parent.width - closeButton.width - 12
                            spacing: 0

                            Text {
                                text: "Battery"
                                color: root.palette.accent
                                font.pixelSize: 14
                                font.bold: true
                            }
                        }

                        Rectangle {
                            id: closeButton

                            width: 34
                            height: 34
                            radius: 8
                            color: closeArea.containsMouse ? root.palette.cardHover : root.palette.cardBackground
                            border.width: 1
                            border.color: root.palette.panelBorder

                            Text {
                                anchors.centerIn: parent
                                text: "X"
                                color: root.palette.primaryText
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
                        height: 100
                        radius: 16
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.criticalAlert ? root.palette.danger : root.palette.panelBorder

                        Row {
                            anchors.fill: parent
                            anchors.margins: 18
                            spacing: 18

                            Text {
                                width: 88
                                verticalAlignment: Text.AlignVCenter
                                text: root.batteryCapacity + "%"
                                color: root.statusColor()
                                font.pixelSize: 34
                                font.bold: true
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                Text {
                                    text: root.batteryStateLabel
                                    color: root.palette.primaryText
                                    font.pixelSize: 20
                                    font.bold: true
                                }

                                Text {
                                    text: root.batteryRemaining.length > 0
                                        ? "Remaining: " + root.batteryRemaining
                                        : "Remaining time unavailable"
                                    color: root.palette.secondaryText
                                    font.pixelSize: 14
                                }

                                Text {
                                    text: "Alert threshold: " + root.alertThreshold + "%"
                                    color: root.palette.mutedText
                                    font.pixelSize: 13
                                }
                            }
                        }
                    }

                    Column {
                        spacing: 10

                        Text {
                            text: "Low-Battery Alert"
                            color: root.palette.secondaryText
                            font.pixelSize: 15
                            font.bold: true
                        }

                        Grid {
                            columns: 3
                            columnSpacing: 8
                            rowSpacing: 8

                            Repeater {
                                model: root.thresholdOptions

                                delegate: Rectangle {
                                    id: thresholdButton

                                    required property int modelData
                                    property bool hovered: false

                                    width: 108
                                    height: 46
                                    radius: 12
                                    color: root.thresholdButtonColor(modelData, hovered)
                                    border.width: 1
                                    border.color: root.alertThreshold === modelData ? root.palette.accentStrong : root.palette.panelBorder

                                    Text {
                                        anchors.centerIn: parent
                                        text: thresholdButton.modelData + "%"
                                        color: root.thresholdTextColor(thresholdButton.modelData)
                                        font.pixelSize: 15
                                        font.bold: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor

                                        onEntered: thresholdButton.hovered = true
                                        onExited: thresholdButton.hovered = false
                                        onClicked: root.applyThreshold(thresholdButton.modelData)
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 64
                        radius: 14
                        color: root.statusTone === "critical"
                            ? Qt.rgba(0.82, 0.53, 0.44, 0.12)
                            : Qt.rgba(0.84, 0.89, 0.92, 0.06)
                        border.width: 1
                        border.color: root.statusTone === "critical" ? root.palette.danger : root.palette.panelBorder

                        Text {
                            anchors.fill: parent
                            anchors.margins: 12
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.WordWrap
                            text: root.statusMessage
                            color: root.statusTone === "critical" ? root.palette.danger : root.palette.secondaryText
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }
}
