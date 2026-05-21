import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string statePath: homeDir + "/.cache/bsdrunner/audio-state"
    readonly property var themeDefinitions: ({
        "default": {
            "name": "Audio",
            "frameBackground": "#111216",
            "panelBackground": "#181b21",
            "cardBackground": "#20242b",
            "frameBorder": "#5b6470",
            "panelBorder": "#7f8794",
            "primaryText": "#eef2f7",
            "secondaryText": "#cfd6df",
            "mutedText": "#a8b1bd",
            "accent": "#d7e3ea",
            "accentStrong": "#f5fbff"
        },
        "jinteki": {
            "name": "Jinteki Audio",
            "frameBackground": "#12090b",
            "panelBackground": "#1c0f12",
            "cardBackground": "#251013",
            "frameBorder": "#8f1f34",
            "panelBorder": "#c61f3a",
            "primaryText": "#fff1f3",
            "secondaryText": "#f2cfd5",
            "mutedText": "#cda9b0",
            "accent": "#ff6f83",
            "accentStrong": "#ffd7dd"
        },
        "haas-bioroid": {
            "name": "Haas-Bioroid Audio",
            "frameBackground": "#0f1418",
            "panelBackground": "#172026",
            "cardBackground": "#1d2830",
            "frameBorder": "#5f7280",
            "panelBorder": "#8fd3ff",
            "primaryText": "#eef7fc",
            "secondaryText": "#d7e3ea",
            "mutedText": "#aebec9",
            "accent": "#8fd3ff",
            "accentStrong": "#dff6ff"
        },
        "nbn": {
            "name": "NBN Audio",
            "frameBackground": "#171108",
            "panelBackground": "#22180a",
            "cardBackground": "#2a1d0a",
            "frameBorder": "#8d6513",
            "panelBorder": "#f3c316",
            "primaryText": "#fff6dd",
            "secondaryText": "#fff0c7",
            "mutedText": "#d8c18a",
            "accent": "#f3c316",
            "accentStrong": "#ffb347"
        },
        "weyland": {
            "name": "Weyland Audio",
            "frameBackground": "#10140f",
            "panelBackground": "#182017",
            "cardBackground": "#212a1d",
            "frameBorder": "#5d8c45",
            "panelBorder": "#b4a14d",
            "primaryText": "#edf3e3",
            "secondaryText": "#dce4d3",
            "mutedText": "#b9c4af",
            "accent": "#5d8c45",
            "accentStrong": "#b4a14d"
        }
    })
    readonly property string activeTheme: {
        var text = themeFile.text().trim()
        return text.length > 0 ? text : "default"
    }
    readonly property var palette: themeDefinitions[activeTheme] || themeDefinitions["default"]

    property int currentVolume: 0
    property bool currentMuted: false

    function refreshState() {
        var text = stateFile.text()
        var lines = text.split("\n")
        var volume = currentVolume
        var muted = currentMuted

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (line.indexOf("volume=") === 0) {
                volume = parseInt(line.slice(7)) || 0
            } else if (line.indexOf("muted=") === 0) {
                muted = line.slice(6).trim() === "1"
            }
        }

        currentVolume = volume
        currentMuted = muted
    }

    function sliderLabel() {
        return currentMuted ? "Muted · " + currentVolume + "%" : "Volume · " + currentVolume + "%"
    }

    function setVolume(value) {
        var rounded = Math.max(0, Math.min(100, Math.round(value)))
        currentVolume = rounded
        Quickshell.execDetached([
            "sh",
            homeDir + "/.config/bsdrunner/scripts/bsdrunner-audio-set.sh",
            String(rounded)
        ])
    }

    function setVolumeFromPosition(mouseX, width) {
        if (width <= 0) return
        var ratio = mouseX / width
        ratio = Math.max(0, Math.min(1, ratio))
        root.setVolume(ratio * 100)
    }

    function toggleMute() {
        currentMuted = !currentMuted
        Quickshell.execDetached([
            "sh",
            homeDir + "/.config/bsdrunner/scripts/bsdrunner-audio-mute.sh"
        ])
    }

    Connections {
        target: Quickshell

        function onLastWindowClosed() {
            Qt.quit()
        }
    }

    FileView {
        id: themeFile
        path: root.homeDir + "/.config/bsdrunner/current-theme"
        blockLoading: true
        watchChanges: true

        onFileChanged: this.reload()
    }

    FileView {
        id: stateFile
        path: root.statePath
        blockLoading: true
        watchChanges: true

        onFileChanged: root.refreshState()
    }

    Timer {
        interval: 1200
        running: true
        repeat: true
        onTriggered: stateFile.reload()
    }

    Component.onCompleted: root.refreshState()

    FloatingWindow {
        id: window

        visible: true
        title: "BSDRunner Audio"
        minimumSize: Qt.size(420, 220)
        maximumSize: Qt.size(420, 220)

        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 22
            color: root.palette.frameBackground
            border.width: 2
            border.color: root.palette.frameBorder

            Rectangle {
                anchors.fill: parent
                anchors.margins: 16
                radius: 16
                color: root.palette.panelBackground
                border.width: 1
                border.color: root.palette.panelBorder

                Column {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 18

                    Text {
                        text: root.palette.name
                        color: root.palette.accent
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Text {
                        text: root.sliderLabel()
                        color: root.palette.primaryText
                        font.pixelSize: 28
                        font.bold: true
                    }

                    Item {
                        width: parent.width
                        height: 34

                        Rectangle {
                            id: sliderTrack

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 10
                            radius: 5
                            color: root.palette.cardBackground
                            border.width: 1
                            border.color: root.palette.frameBorder

                            Rectangle {
                                width: Math.max(10, (root.currentVolume / 100) * parent.width)
                                height: parent.height
                                radius: 5
                                color: root.palette.accent
                            }

                            Rectangle {
                                width: 22
                                height: 22
                                radius: 11
                                color: root.palette.accentStrong
                                border.width: 2
                                border.color: root.palette.accent
                                x: Math.max(0, Math.min(parent.width - width, (root.currentVolume / 100) * parent.width - width / 2))
                                y: (parent.height - height) / 2
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onPressed: root.setVolumeFromPosition(mouse.x, width)
                                onPositionChanged: {
                                    if (pressed) {
                                        root.setVolumeFromPosition(mouse.x, width)
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        spacing: 12

                        Rectangle {
                            width: 120
                            height: 42
                            radius: 12
                            color: root.palette.cardBackground
                            border.width: 1
                            border.color: root.palette.frameBorder

                            Text {
                                anchors.centerIn: parent
                                text: root.currentMuted ? "Unmute" : "Mute"
                                color: root.palette.primaryText
                                font.pixelSize: 16
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.color = root.palette.frameBackground
                                onExited: parent.color = root.palette.cardBackground
                                onClicked: root.toggleMute()
                            }
                        }

                        Rectangle {
                            width: 120
                            height: 42
                            radius: 12
                            color: root.palette.cardBackground
                            border.width: 1
                            border.color: root.palette.frameBorder

                            Text {
                                anchors.centerIn: parent
                                text: "Close"
                                color: root.palette.primaryText
                                font.pixelSize: 16
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.color = root.palette.frameBackground
                                onExited: parent.color = root.palette.cardBackground
                                onClicked: Qt.quit()
                            }
                        }
                    }
                }
            }
        }
    }
}
