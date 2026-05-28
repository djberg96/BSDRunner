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
    readonly property string activeTheme: themeLoader.activeTheme
    readonly property string homeDir: themeLoader.homeDir
    property string wallpaperPath: ""
    property string wallpaperStdoutText: ""
    property bool wallpaperExited: false
    property bool wallpaperStdoutFinished: false
    property string usernameText: ""
    property string passwordText: ""
    property string selectedSession: "BSDRunner"
    property bool sessionMenuOpen: false
    property string feedbackTone: "info"
    property string feedbackTitle: ""
    property string feedbackText: ""

    property var sessions: [
        {
            "label": "BSDRunner"
        },
        {
            "label": "Terminal"
        }
    ]

    function wallpaperUrl() {
        if (!wallpaperPath || wallpaperPath.length === 0)
            return ""
        return "file://" + wallpaperPath
    }

    function maybeApplyWallpaper() {
        if (!wallpaperExited || !wallpaperStdoutFinished)
            return

        wallpaperPath = wallpaperStdoutText.trim()
    }

    function requestLogin() {
        if (usernameText.trim().length === 0 || passwordText.length === 0) {
            feedbackTone = "error"
            feedbackTitle = "Missing Credentials"
            feedbackText = "Enter both a username and a password before trying to sign in."
            return
        }

        feedbackTone = "warning"
        feedbackTitle = "Sign In Is Not Wired Yet"
        feedbackText = "Authentication and session startup still need a backend."
    }

    function requestPower(actionName) {
        feedbackTone = "info"
        feedbackTitle = actionName + " Is Not Wired Yet"
        feedbackText = "Power controls still need a backend."
    }

    function triggerButton(actionId) {
        switch (actionId) {
        case "login":
            requestLogin()
            break
        case "shutdown":
            requestPower("Shutdown")
            break
        case "restart":
            requestPower("Restart")
            break
        }
    }

    Connections {
        target: Quickshell

        function onLastWindowClosed() {
            Qt.quit()
        }
    }

    Process {
        id: wallpaperProcess
        property var controller: root

        command: [
            "sh",
            themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-greeter-wallpaper.sh",
            root.activeTheme
        ]
        running: true

        stdout: StdioCollector {
            waitForEnd: true

            onStreamFinished: {
                wallpaperProcess.controller.wallpaperStdoutText = text
                wallpaperProcess.controller.wallpaperStdoutFinished = true
                wallpaperProcess.controller.maybeApplyWallpaper()
            }
        }

        onExited: function(exitCode, exitStatus) {
            wallpaperProcess.controller.wallpaperExited = true
            wallpaperProcess.controller.maybeApplyWallpaper()
        }
    }

    FloatingWindow {
        id: window

        visible: true
        title: "BSDRunner"
        minimumSize: Qt.size(1440, 900)
        maximumSize: Qt.size(1440, 900)
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: root.palette.frameBackground

            Image {
                anchors.fill: parent
                source: root.wallpaperUrl()
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                visible: root.wallpaperPath.length > 0
            }

            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: 0.34
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(0.03, 0.04, 0.05, 0.68) }
                    GradientStop { position: 0.55; color: Qt.rgba(0.03, 0.04, 0.05, 0.28) }
                    GradientStop { position: 1.0; color: Qt.rgba(0.03, 0.04, 0.05, 0.76) }
                }
            }

            Item {
                anchors.fill: parent
                anchors.margins: 54

                Rectangle {
                    width: 780
                    height: 440
                    anchors.centerIn: parent
                    radius: 28
                    color: Qt.rgba(0.04, 0.05, 0.06, 0.68)
                    border.width: 2
                    border.color: root.palette.frameBorder

                    Row {
                        anchors.centerIn: parent
                        spacing: 28

                        Column {
                            width: 460
                            spacing: 18

                            Text {
                                width: parent.width
                                text: "Sign In"
                                color: root.palette.primaryText
                                font.pixelSize: 40
                                font.bold: true
                            }

                            Rectangle {
                                width: parent.width
                                height: 62
                                radius: 18
                                color: root.palette.cardBackground
                                border.width: 1
                                border.color: root.palette.panelBorder

                                TextInput {
                                    id: usernameInput
                                    anchors.fill: parent
                                    anchors.margins: 18
                                    color: root.palette.primaryText
                                    selectionColor: root.palette.accent
                                    selectedTextColor: root.palette.frameBackground
                                    font.pixelSize: 18
                                    text: root.usernameText

                                    onTextChanged: {
                                        root.usernameText = text
                                        if (text.length > 0 && root.feedbackTone !== "error") {
                                            root.feedbackTitle = ""
                                            root.feedbackText = ""
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: parent.text.length === 0
                                        text: "Username"
                                        color: root.palette.mutedText
                                        font.pixelSize: 18
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 62
                                radius: 18
                                color: root.palette.cardBackground
                                border.width: 1
                                border.color: root.palette.panelBorder

                                TextInput {
                                    id: passwordInput
                                    anchors.fill: parent
                                    anchors.margins: 18
                                    color: root.palette.primaryText
                                    selectionColor: root.palette.accent
                                    selectedTextColor: root.palette.frameBackground
                                    font.pixelSize: 18
                                    echoMode: TextInput.Password
                                    text: root.passwordText

                                    onTextChanged: {
                                        root.passwordText = text
                                        if (text.length > 0 && root.feedbackTone !== "error") {
                                            root.feedbackTitle = ""
                                            root.feedbackText = ""
                                        }
                                    }

                                    Keys.onReturnPressed: root.requestLogin()

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: parent.text.length === 0
                                        text: "Password"
                                        color: root.palette.mutedText
                                        font.pixelSize: 18
                                    }
                                }
                            }

                            Item {
                                width: parent.width
                                height: root.feedbackTitle.length > 0 || root.feedbackText.length > 0
                                    ? feedbackCard.height
                                    : 0

                                Rectangle {
                                    id: feedbackCard
                                    visible: root.feedbackTitle.length > 0 || root.feedbackText.length > 0
                                    width: parent.width
                                    height: feedbackColumn.implicitHeight + 26
                                    radius: 18
                                    color: root.palette.cardBackground
                                    border.width: 2
                                    border.color: root.feedbackTone === "error"
                                        ? root.palette.danger
                                        : root.feedbackTone === "warning"
                                            ? root.palette.warning
                                            : root.palette.panelBorder

                                    Column {
                                        id: feedbackColumn
                                        anchors.fill: parent
                                        anchors.margins: 18
                                        spacing: 6

                                        Text {
                                            text: root.feedbackTitle
                                            color: root.feedbackTone === "error"
                                                ? root.palette.danger
                                                : root.feedbackTone === "warning"
                                                    ? root.palette.warning
                                                    : root.palette.primaryText
                                            font.pixelSize: 17
                                            font.bold: true
                                        }

                                        Text {
                                            width: parent.width
                                            text: root.feedbackText
                                            color: root.palette.secondaryText
                                            font.pixelSize: 15
                                            wrapMode: Text.WordWrap
                                            lineHeight: 1.12
                                        }
                                    }
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: 12

                                Repeater {
                                    model: [
                                        {
                                            "id": "login",
                                            "label": "Sign In",
                                            "accent": themeLoader.actionAccent("login")
                                        },
                                        {
                                            "id": "shutdown",
                                            "label": "Shutdown",
                                            "accent": themeLoader.actionAccent("shutdown")
                                        },
                                        {
                                            "id": "restart",
                                            "label": "Restart",
                                            "accent": themeLoader.actionAccent("restart")
                                        }
                                    ]

                                    delegate: Rectangle {
                                        required property var modelData
                                        width: (parent.width - 24) / 3
                                        height: 66
                                        radius: 18
                                        color: Qt.rgba(0.05, 0.06, 0.08, 0.48)
                                        border.width: 2
                                        border.color: modelData.accent

                                        Text {
                                            anchors.centerIn: parent
                                            text: parent.modelData.label
                                            color: parent.modelData.accent
                                            font.pixelSize: 18
                                            font.bold: true
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor

                                            onEntered: parent.color = root.palette.cardHover
                                            onExited: parent.color = Qt.rgba(0.05, 0.06, 0.08, 0.48)
                                            onClicked: root.triggerButton(parent.modelData.id)
                                        }
                                    }
                                }
                            }
                        }

                        Column {
                            width: 220
                            spacing: 10

                            Text {
                                text: "Session"
                                color: root.palette.mutedText
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Rectangle {
                                width: parent.width
                                height: 58
                                radius: 18
                                color: root.palette.cardBackground
                                border.width: 1
                                border.color: root.palette.panelBorder

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 18
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.selectedSession
                                    color: root.palette.primaryText
                                    font.pixelSize: 17
                                    font.bold: true
                                }

                                Text {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 18
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.sessionMenuOpen ? "˄" : "˅"
                                    color: root.palette.accentStrong
                                    font.pixelSize: 18
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.sessionMenuOpen = !root.sessionMenuOpen
                                }
                            }

                            Rectangle {
                                visible: root.sessionMenuOpen
                                width: parent.width
                                height: sessionMenuColumn.implicitHeight + 16
                                radius: 18
                                color: Qt.rgba(0.05, 0.06, 0.08, 0.92)
                                border.width: 1
                                border.color: root.palette.panelBorder

                                Column {
                                    id: sessionMenuColumn
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 6

                                    Repeater {
                                        model: root.sessions

                                        delegate: Rectangle {
                                            id: sessionOption
                                            required property var modelData
                                            readonly property bool active: root.selectedSession === modelData.label
                                            width: parent.width
                                            height: 44
                                            radius: 12
                                            color: sessionOption.active ? root.palette.cardHover : "transparent"
                                            border.width: sessionOption.active ? 1 : 0
                                            border.color: sessionOption.active ? themeLoader.actionAccent("session") : "transparent"

                                            Text {
                                                anchors.centerIn: parent
                                                text: sessionOption.modelData.label
                                                color: sessionOption.active ? root.palette.accentStrong : root.palette.primaryText
                                                font.pixelSize: 15
                                                font.bold: true
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.selectedSession = parent.modelData.label
                                                    root.sessionMenuOpen = false
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
