import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property var themeDefinitions: ({
        "default": {
            "name": "BSDRunner",
            "eyebrow": "BSDRunner",
            "frameBackground": "#111216",
            "panelBackground": "#181b21",
            "cardBackground": "#20242b",
            "cardHover": "#2a3038",
            "frameBorder": "#5b6470",
            "panelBorder": "#7f8794",
            "primaryText": "#eef2f7",
            "secondaryText": "#cfd6df",
            "mutedText": "#a8b1bd",
            "accent": "#d7e3ea",
            "accentStrong": "#f5fbff",
            "actionAccents": {
                "terminal": "#d7e3ea",
                "files": "#c4d4e2",
                "browser": "#ffb86b",
                "reload": "#8eb6d6",
                "power": "#f5fbff",
                "close": "#ffffff"
            }
        },
        "jinteki": {
            "name": "Jinteki",
            "eyebrow": "BSDRunner",
            "frameBackground": "#12090b",
            "panelBackground": "#1c0f12",
            "cardBackground": "#251013",
            "cardHover": "#341417",
            "frameBorder": "#8f1f34",
            "panelBorder": "#c61f3a",
            "primaryText": "#fff1f3",
            "secondaryText": "#f2cfd5",
            "mutedText": "#cda9b0",
            "accent": "#ff6f83",
            "accentStrong": "#ffd7dd",
            "actionAccents": {
                "terminal": "#ff6f83",
                "files": "#f0c0b7",
                "browser": "#ffb36b",
                "reload": "#ff8795",
                "power": "#ffd7dd",
                "close": "#ffffff"
            }
        },
        "haas-bioroid": {
            "name": "Haas-Bioroid",
            "eyebrow": "BSDRunner",
            "frameBackground": "#0f1418",
            "panelBackground": "#172026",
            "cardBackground": "#1d2830",
            "cardHover": "#283741",
            "frameBorder": "#5f7280",
            "panelBorder": "#8fd3ff",
            "primaryText": "#eef7fc",
            "secondaryText": "#d7e3ea",
            "mutedText": "#aebec9",
            "accent": "#8fd3ff",
            "accentStrong": "#dff6ff",
            "actionAccents": {
                "terminal": "#8fd3ff",
                "files": "#dff6ff",
                "browser": "#ffb86b",
                "reload": "#9fcfe8",
                "power": "#bde9ff",
                "close": "#f5fbff"
            }
        },
        "nbn": {
            "name": "NBN",
            "eyebrow": "BSDRunner",
            "frameBackground": "#171108",
            "panelBackground": "#22180a",
            "cardBackground": "#2a1d0a",
            "cardHover": "#3a280b",
            "frameBorder": "#8d6513",
            "panelBorder": "#f3c316",
            "primaryText": "#fff6dd",
            "secondaryText": "#fff0c7",
            "mutedText": "#d8c18a",
            "accent": "#f3c316",
            "accentStrong": "#ffb347",
            "actionAccents": {
                "terminal": "#f3c316",
                "files": "#ffd76a",
                "browser": "#ffb347",
                "reload": "#ffcf5a",
                "power": "#fff0c7",
                "close": "#fffaf0"
            }
        },
        "weyland": {
            "name": "Weyland",
            "eyebrow": "BSDRunner",
            "frameBackground": "#10140f",
            "panelBackground": "#182017",
            "cardBackground": "#212a1d",
            "cardHover": "#2d3827",
            "frameBorder": "#5d8c45",
            "panelBorder": "#b4a14d",
            "primaryText": "#edf3e3",
            "secondaryText": "#dce4d3",
            "mutedText": "#b9c4af",
            "accent": "#5d8c45",
            "accentStrong": "#b4a14d",
            "actionAccents": {
                "terminal": "#5d8c45",
                "files": "#b4a14d",
                "browser": "#d9a15d",
                "reload": "#88a16c",
                "power": "#dce4d3",
                "close": "#f1f4eb"
            }
        }
    })
    readonly property string activeTheme: {
        var text = themeFile.text().trim()
        return text.length > 0 ? text : "default"
    }
    readonly property var palette: themeDefinitions[activeTheme] || themeDefinitions["default"]

    function actionThemeName(action) {
        if (action.indexOf("theme:") !== 0) return ""
        return action.slice(6)
    }

    function actionAccent(action) {
        var accents = root.palette.actionAccents || {}
        return accents[action] || root.palette.accent
    }

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

    FileView {
        id: themeFile
        path: root.homeDir + "/.config/bsdrunner/current-theme"
        blockLoading: true
        watchChanges: true

        onFileChanged: this.reload()
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
                "action": "terminal"
            },
            {
                "title": "Open Files",
                "subtitle": "Launch dolphin",
                "action": "files"
            },
            {
                "title": "Open Browser",
                "subtitle": "Launch firefox",
                "action": "browser"
            },
            {
                "title": "Reload Hyprland",
                "subtitle": "Reload the live config",
                "action": "reload"
            },
            {
                "title": "Power Menu",
                "subtitle": "Open the BSDRunner shutdown menu",
                "action": "power"
            },
            {
                "title": "Close",
                "subtitle": "Dismiss this welcome window",
                "action": "close"
            }
        ]

        property var themeCards: [
            {
                "short": "DEF",
                "title": "Default",
                "subtitle": "Neutral baseline",
                "accent": "#d7e3ea",
                "action": "theme:default"
            },
            {
                "short": "JIN",
                "title": "Jinteki",
                "subtitle": "Crimson lacquer",
                "accent": "#ff6f83",
                "action": "theme:jinteki"
            },
            {
                "short": "HB",
                "title": "Haas-Bioroid",
                "subtitle": "Steel and cyan",
                "accent": "#8fd3ff",
                "action": "theme:haas-bioroid"
            },
            {
                "short": "NBN",
                "title": "NBN",
                "subtitle": "Broadcast gold",
                "accent": "#f3c316",
                "action": "theme:nbn"
            },
            {
                "short": "WYL",
                "title": "Weyland",
                "subtitle": "Industrial green",
                "accent": "#5d8c45",
                "action": "theme:weyland"
            }
        ]

        Rectangle {
            anchors.fill: parent
            radius: 24
            color: root.palette.frameBackground
            border.width: 2
            border.color: root.palette.frameBorder

            Rectangle {
                anchors.fill: parent
                anchors.margins: 18
                radius: 18
                color: root.palette.panelBackground
                border.width: 1
                border.color: root.palette.panelBorder

                Column {
                    anchors.fill: parent
                    anchors.margins: 28
                    spacing: 20

                    Column {
                        spacing: 8

                        Text {
                            text: root.palette.eyebrow
                            color: root.palette.accent
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Text {
                            text: "Welcome to the " + root.palette.name + " Desktop."
                            color: root.palette.primaryText
                            font.pixelSize: 34
                            font.bold: true
                        }
                    }

                    Column {
                        spacing: 12

                        Text {
                            text: "Select Theme"
                            color: root.palette.secondaryText
                            font.pixelSize: 16
                            font.bold: true
                        }

                        Row {
                            spacing: 8

                            Repeater {
                                model: window.themeCards

                                delegate: Column {
                                    required property var modelData

                                    property bool isSelected: root.activeTheme === root.actionThemeName(modelData.action)
                                    width: 160
                                    spacing: 8

                                    Rectangle {
                                        id: themeCircle

                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 88
                                        height: 88
                                        radius: 44
                                        color: parent.isSelected ? root.palette.cardHover : root.palette.cardBackground
                                        border.width: 3
                                        border.color: parent.isSelected ? root.palette.accentStrong : parent.modelData.accent

                                        Text {
                                            anchors.centerIn: parent
                                            text: parent.parent.modelData.short
                                            color: parent.parent.modelData.accent
                                            font.pixelSize: 22
                                            font.bold: true
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor

                                            onEntered: themeCircle.color = root.palette.cardHover
                                            onExited: themeCircle.color = parent.parent.isSelected ? root.palette.cardHover : root.palette.cardBackground
                                            onClicked: root.runAction(parent.parent.modelData.action)
                                        }
                                    }

                                    Text {
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.WordWrap
                                        text: modelData.title
                                        color: root.palette.primaryText
                                        font.pixelSize: 13
                                        font.bold: parent.isSelected
                                    }
                                }
                            }
                        }
                    }

                    Grid {
                        columns: 3
                        rowSpacing: 14
                        columnSpacing: 14

                        Repeater {
                            model: window.cards

                            delegate: Rectangle {
                                required property var modelData
                                readonly property color accentColor: root.actionAccent(modelData.action)

                                width: 256
                                height: 96
                                radius: 18
                                color: root.palette.cardBackground
                                border.width: 2
                                border.color: accentColor

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 4

                                    Text {
                                        text: parent.parent.modelData.title
                                        color: parent.parent.accentColor
                                        font.pixelSize: 19
                                        font.bold: true
                                    }

                                    Text {
                                        width: 220
                                        wrapMode: Text.WordWrap
                                        text: parent.parent.modelData.subtitle
                                        color: root.palette.primaryText
                                        font.pixelSize: 14
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onEntered: parent.color = root.palette.cardHover
                                    onExited: parent.color = root.palette.cardBackground
                                    onClicked: root.runAction(parent.modelData.action)
                                }
                            }
                        }
                    }

                    Text {
                        text: "Enable startup later with: touch ~/.config/bsdrunner/show-welcome-at-startup"
                        color: root.palette.mutedText
                        font.pixelSize: 14
                    }
                }
            }
        }
    }
}
