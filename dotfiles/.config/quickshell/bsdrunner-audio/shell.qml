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
    readonly property string statePath: homeDir + "/.cache/bsdrunner/audio-state"
    readonly property string activeTheme: {
        var text = themeFile.text().trim()
        return text.length > 0 ? text : "default"
    }
    readonly property string palettePath: homeDir + "/.config/bsdrunner/themes/" + activeTheme + "/palette.conf"

    property int currentVolume: 0
    property bool currentMuted: false
    property bool dragging: false
    property bool applyInFlight: false

    function paletteValue(key, fallback) {
        var lines = paletteFile.text().split("\n")
        for (var i = 0; i < lines.length; i += 1) {
            var line = lines[i].trim()
            if (line.indexOf(key + "=") === 0)
                return line.substring(key.length + 1).trim()
        }
        return fallback
    }

    readonly property color backgroundColor: paletteValue("background", "#101418")
    readonly property color surfaceColor: paletteValue("surface", "#1a2128")
    readonly property color textColor: paletteValue("text", "#d8e1ea")
    readonly property color accentColor: paletteValue("accent", "#6aa9d8")
    readonly property color accentStrongColor: paletteValue("accent_strong", "#b7d9f2")

    function refreshState() {
        if (dragging || applyInFlight)
            return

        var lines = stateFile.text().split("\n")
        var volume = currentVolume
        var muted = currentMuted

        for (var i = 0; i < lines.length; i += 1) {
            var line = lines[i]
            if (line.indexOf("volume=") === 0)
                volume = parseInt(line.slice(7)) || 0
            else if (line.indexOf("muted=") === 0)
                muted = line.slice(6).trim() === "1"
        }

        currentVolume = Math.max(0, Math.min(100, volume))
        currentMuted = muted
    }

    function previewVolume(value) {
        var rounded = Math.max(0, Math.min(100, Math.round(value)))
        currentVolume = rounded
    }

    function commitVolume(value) {
        var rounded = Math.max(0, Math.min(100, Math.round(value)))
        currentVolume = rounded
        applyInFlight = true
        applyTimeout.restart()
        Quickshell.execDetached([
            "sh",
            homeDir + "/.config/bsdrunner/scripts/bsdrunner-audio-set.sh",
            String(rounded)
        ])
    }

    function setVolumeFromPosition(mouseX, width) {
        if (width <= 0)
            return
        previewVolume((Math.max(0, Math.min(width, mouseX)) / width) * 100)
    }

    function toggleMute() {
        currentMuted = !currentMuted
        applyInFlight = true
        applyTimeout.restart()
        Quickshell.execDetached([
            "sh",
            homeDir + "/.config/bsdrunner/scripts/bsdrunner-audio-mute.sh"
        ])
    }

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

    FileView {
        id: stateFile
        path: root.statePath
        blockLoading: true
        watchChanges: true

        onFileChanged: {
            this.reload()
            root.applyInFlight = false
            applyTimeout.stop()
            root.refreshState()
        }
    }

    Timer {
        id: applyTimeout
        interval: 1500
        repeat: false

        onTriggered: {
            root.applyInFlight = false
            stateFile.reload()
            root.refreshState()
        }
    }

    Timer {
        interval: 1200
        running: true
        repeat: true

        onTriggered: {
            stateFile.reload()
            root.refreshState()
        }
    }

    Component.onCompleted: refreshState()

    Connections {
        target: Quickshell

        function onLastWindowClosed() {
            Qt.quit()
        }
    }

    FloatingWindow {
        id: window
        visible: true
        title: "BSDRunner Master Volume"
        minimumSize: Qt.size(420, 210)
        maximumSize: Qt.size(420, 210)
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 22
            color: root.backgroundColor
            border.width: 2
            border.color: Qt.alpha(root.accentColor, 0.48)

            Rectangle {
                anchors.fill: parent
                anchors.margins: 14
                radius: 18
                color: root.surfaceColor
                border.width: 1
                border.color: Qt.alpha(root.accentColor, 0.34)

                Column {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    Text {
                        text: "Master Output"
                        color: root.accentColor
                        font.pixelSize: 17
                        font.bold: true
                    }

                    Text {
                        text: root.currentMuted ? "Muted · " + root.currentVolume + "%" : "Volume · " + root.currentVolume + "%"
                        color: root.textColor
                        font.pixelSize: 24
                        font.bold: true
                    }

                    Item {
                        width: parent.width
                        height: 28

                        Rectangle {
                            id: sliderTrack
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 10
                            radius: 5
                            color: Qt.alpha(root.backgroundColor, 0.72)
                            border.width: 1
                            border.color: Qt.alpha(root.accentColor, 0.38)

                            Rectangle {
                                width: Math.max(10, (root.currentVolume / 100) * parent.width)
                                height: parent.height
                                radius: 5
                                color: root.accentColor
                            }

                            Rectangle {
                                width: 22
                                height: 22
                                radius: 11
                                color: root.accentStrongColor
                                border.width: 2
                                border.color: root.accentColor
                                x: Math.max(0, Math.min(parent.width - width, (root.currentVolume / 100) * parent.width - width / 2))
                                y: (parent.height - height) / 2
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onPressed: mouse => {
                                    root.dragging = true
                                    root.setVolumeFromPosition(mouse.x, width)
                                }
                                onPositionChanged: mouse => {
                                    if (pressed)
                                        root.setVolumeFromPosition(mouse.x, width)
                                }
                                onReleased: {
                                    root.dragging = false
                                    root.commitVolume(root.currentVolume)
                                }
                                onCanceled: {
                                    root.dragging = false
                                    stateFile.reload()
                                    root.refreshState()
                                }
                            }
                        }
                    }

                    Row {
                        spacing: 12

                        Rectangle {
                            width: 110
                            height: 36
                            radius: 10
                            color: muteArea.containsMouse ? Qt.alpha(root.accentColor, 0.24) : Qt.alpha(root.backgroundColor, 0.72)
                            border.width: 1
                            border.color: Qt.alpha(root.accentColor, 0.38)

                            Text {
                                anchors.centerIn: parent
                                text: root.currentMuted ? "Unmute" : "Mute"
                                color: root.textColor
                                font.pixelSize: 15
                                font.bold: true
                            }

                            MouseArea {
                                id: muteArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleMute()
                            }
                        }

                        Rectangle {
                            width: 110
                            height: 36
                            radius: 10
                            color: closeArea.containsMouse ? Qt.alpha(root.accentColor, 0.24) : Qt.alpha(root.backgroundColor, 0.72)
                            border.width: 1
                            border.color: Qt.alpha(root.accentColor, 0.38)

                            Text {
                                anchors.centerIn: parent
                                text: "Close"
                                color: root.textColor
                                font.pixelSize: 15
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
                }
            }
        }
    }
}
