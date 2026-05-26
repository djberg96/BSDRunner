pragma ComponentBehavior: Bound

import Quickshell
import QtCore
import QtQuick

ShellRoot {
    id: root

    ThemeLoader {
        id: themeLoader
    }

    function localPath(value) {
        var text = String(value || "")
        if (text.indexOf("file://") === 0)
            return decodeURIComponent(text.replace(/^file:\/+/, "/"))
        return text
    }

    readonly property string homeDir: localPath(StandardPaths.writableLocation(StandardPaths.HomeLocation))
    readonly property string activeTheme: themeLoader.activeTheme
    readonly property var palette: themeLoader.palette

    function actionThemeName(action) {
        if (action.indexOf("theme:") !== 0) return ""
        return action.slice(6)
    }

    function actionAccent(action) {
        return themeLoader.actionAccent(action)
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
                "title": "Open Apps",
                "subtitle": "Launch BSDRunner Software",
                "action": "apps"
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
                                    id: themeCard

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
                                        color: themeCard.isSelected ? root.palette.cardHover : root.palette.cardBackground
                                        border.width: 3
                                        border.color: themeCard.isSelected ? root.palette.accentStrong : themeCard.modelData.accent

                                        Text {
                                            anchors.centerIn: parent
                                            text: themeCard.modelData.short
                                            color: themeCard.modelData.accent
                                            font.pixelSize: 22
                                            font.bold: true
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor

                                            onEntered: themeCircle.color = root.palette.cardHover
                                            onExited: themeCircle.color = themeCard.isSelected ? root.palette.cardHover : root.palette.cardBackground
                                            onClicked: root.runAction(themeCard.modelData.action)
                                        }
                                    }

                                    Text {
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.WordWrap
                                        text: themeCard.modelData.title
                                        color: root.palette.primaryText
                                        font.pixelSize: 13
                                        font.bold: themeCard.isSelected
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
                                id: actionCard

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
                                        text: actionCard.modelData.title
                                        color: actionCard.accentColor
                                        font.pixelSize: 19
                                        font.bold: true
                                    }

                                    Text {
                                        width: 220
                                        wrapMode: Text.WordWrap
                                        text: actionCard.modelData.subtitle
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
                                    onClicked: root.runAction(actionCard.modelData.action)
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
