import Quickshell
import QtQuick

ShellRoot {
    id: root

    readonly property string homeDir: Quickshell.env("HOME") || ""

    function runAction(action) {
        if (action === "close") {
            Qt.quit()
            return
        }

        Quickshell.execDetached([
            "sh",
            homeDir + "/.config/bsdrunner/scripts/bsdrunner-welcome-action.sh",
            action
        ])
        Qt.quit()
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
        title: "BSDRunner Welcome"
        minimumSize: Qt.size(920, 620)
        maximumSize: Qt.size(920, 620)

        color: "transparent"

        property var cards: [
            {
                "title": "Open Terminal",
                "subtitle": "Launch kitty",
                "accent": "#ff6f83",
                "action": "terminal"
            },
            {
                "title": "Open Files",
                "subtitle": "Launch dolphin",
                "accent": "#f0c0b7",
                "action": "files"
            },
            {
                "title": "Open Browser",
                "subtitle": "Launch firefox",
                "accent": "#ffb36b",
                "action": "browser"
            },
            {
                "title": "Reload Hyprland",
                "subtitle": "Reload the live config",
                "accent": "#ff8795",
                "action": "reload"
            },
            {
                "title": "Power Menu",
                "subtitle": "Open the BSDRunner shutdown menu",
                "accent": "#ffd7dd",
                "action": "power"
            },
            {
                "title": "Close",
                "subtitle": "Dismiss this welcome window",
                "accent": "#ffffff",
                "action": "close"
            }
        ]

        Rectangle {
            anchors.fill: parent
            radius: 24
            color: "#12090b"
            border.width: 2
            border.color: "#8f1f34"

            Rectangle {
                anchors.fill: parent
                anchors.margins: 18
                radius: 18
                color: "#1c0f12"
                border.width: 1
                border.color: "#c61f3a"

                Column {
                    anchors.fill: parent
                    anchors.margins: 28
                    spacing: 20

                    Column {
                        spacing: 8

                        Text {
                            text: "BSDRunner"
                            color: "#ffb0bb"
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Text {
                            text: "Welcome to the Jinteki Desktop."
                            color: "#fff1f3"
                            font.pixelSize: 34
                            font.bold: true
                        }
                    }

                    Grid {
                        columns: 2
                        rowSpacing: 14
                        columnSpacing: 14

                        Repeater {
                            model: window.cards

                            delegate: Rectangle {
                                required property var modelData

                                width: 394
                                height: 112
                                radius: 18
                                color: "#251013"
                                border.width: 2
                                border.color: modelData.accent

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 18
                                    spacing: 6

                                    Text {
                                        text: parent.parent.modelData.title
                                        color: parent.parent.modelData.accent
                                        font.pixelSize: 22
                                        font.bold: true
                                    }

                                    Text {
                                        width: 320
                                        wrapMode: Text.WordWrap
                                        text: parent.parent.modelData.subtitle
                                        color: "#fff1f3"
                                        font.pixelSize: 15
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onEntered: parent.color = "#341417"
                                    onExited: parent.color = "#251013"
                                    onClicked: root.runAction(parent.modelData.action)
                                }
                            }
                        }
                    }

                    Text {
                        text: "Enable startup later with: touch ~/.config/bsdrunner/show-welcome-at-startup"
                        color: "#cda9b0"
                        font.pixelSize: 14
                    }
                }
            }
        }
    }
}
