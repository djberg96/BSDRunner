pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtCore
import QtQuick
import QtQuick.Controls

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
    property string freebsdTip: ""
    property bool tipOpen: false

    Process {
        command: ["/usr/bin/fortune", "freebsd-tips"]
        running: true
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.freebsdTip = text.trim()
        }
    }

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
                "subtitle": "Open the app launcher",
                "action": "apps"
            },
            {
                "title": "Key Bindings",
                "subtitle": "View every desktop key binding",
                "action": "keybindings"
            },
            {
                "title": "Power Menu",
                "subtitle": "Open the BSDRunner shutdown menu",
                "action": "power"
            },
            {
                "title": "System Settings",
                "subtitle": "Configure the BSDRunner desktop",
                "action": "settings"
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
                        columns: 4
                        rowSpacing: 14
                        columnSpacing: 14

                        Repeater {
                            model: window.cards

                            delegate: Rectangle {
                                id: actionCard

                                required property var modelData
                                readonly property color accentColor: root.actionAccent(modelData.action)

                                width: 190
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
                                        width: 158
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

                }

                Button {
                    id: tipButton
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 24
                    width: 100
                    height: 40
                    text: "MOTD"
                    onClicked: {
                        root.tipOpen = true
                        tipDialog.forceActiveFocus()
                    }
                    background: Rectangle {
                        radius: 12
                        color: tipButton.hovered || tipButton.visualFocus ? root.palette.cardHover : root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.accent
                    }
                    contentItem: Text {
                        text: tipButton.text
                        color: root.palette.primaryText
                        font.pixelSize: 15
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            FocusScope {
                id: tipDialog
                anchors.fill: parent
                visible: root.tipOpen
                z: 10
                Keys.onEscapePressed: {
                    root.tipOpen = false
                    tipButton.forceActiveFocus()
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 24
                    color: "#bb000000"
                    MouseArea { anchors.fill: parent }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(700, parent.width - 80)
                    height: Math.min(440, parent.height - 80)
                    radius: 22
                    color: root.palette.panelBackground
                    border.width: 2
                    border.color: root.palette.frameBorder

                    Text {
                        id: tipHeading
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 28
                        text: "FreeBSD Tip"
                        color: root.palette.accent
                        font.pixelSize: 24
                        font.bold: true
                    }

                    Flickable {
                        id: tipScroll
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: tipHeading.bottom
                        anchors.bottom: closeTip.top
                        anchors.margins: 28
                        contentWidth: width
                        contentHeight: tipText.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        Text {
                            id: tipText
                            width: tipScroll.width - 16
                            text: root.freebsdTip || "No FreeBSD tip is available."
                            textFormat: Text.PlainText
                            color: root.palette.primaryText
                            font.pixelSize: 18
                            wrapMode: Text.Wrap
                        }
                    }

                    Button {
                        id: closeTip
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 24
                        width: 130
                        height: 44
                        text: "Close"
                        focus: true
                        Keys.onTabPressed: function(event) { event.accepted = true }
                        Keys.onBacktabPressed: function(event) { event.accepted = true }
                        onClicked: {
                            root.tipOpen = false
                            tipButton.forceActiveFocus()
                        }
                        background: Rectangle {
                            radius: 12
                            color: closeTip.hovered || closeTip.visualFocus ? root.palette.cardHover : root.palette.cardBackground
                            border.width: 1
                            border.color: root.palette.accent
                        }
                        contentItem: Text {
                            text: closeTip.text
                            color: root.palette.primaryText
                            font.pixelSize: 16
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
    }
}
