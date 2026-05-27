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
    property string selectedSession: "Hyprland"
    property string feedbackTone: "info"
    property string feedbackTitle: "Native Greeter UI Prototype"
    property string feedbackText: "UI only for now. Authentication and session startup backends are not wired yet."

    property var sessions: [
        {
            "label": "Hyprland",
            "subtitle": "BSDRunner default desktop"
        },
        {
            "label": "Failsafe",
            "subtitle": "Minimal shell session"
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
        feedbackTitle = "Backend Not Wired Yet"
        feedbackText = "This BSDRunner greeter is a Quickshell UI prototype. PAM authentication and real session launch still need a privileged backend."
    }

    function requestPower(actionName) {
        feedbackTone = "info"
        feedbackTitle = actionName + " Placeholder"
        feedbackText = "Power controls are not wired into the greeter backend yet."
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

        command: ["sh", themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-greeter-wallpaper.sh"]
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
        title: "BSDRunner Greeter"
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

            Row {
                anchors.fill: parent
                anchors.margins: 54
                spacing: 28

                Rectangle {
                    width: 470
                    height: parent.height
                    radius: 28
                    color: Qt.rgba(0.04, 0.05, 0.06, 0.58)
                    border.width: 2
                    border.color: root.palette.frameBorder

                    Column {
                        anchors.fill: parent
                        anchors.margins: 34
                        spacing: 22

                        Text {
                            text: root.palette.eyebrow
                            color: root.palette.accent
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Text {
                            width: parent.width
                            text: "BSDRunner Greeter"
                            color: root.palette.primaryText
                            font.pixelSize: 44
                            font.bold: true
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            width: parent.width
                            text: "A native Quickshell login surface for the " + root.palette.name + " desktop."
                            color: root.palette.secondaryText
                            font.pixelSize: 20
                            wrapMode: Text.WordWrap
                            lineHeight: 1.18
                        }

                        Rectangle {
                            width: parent.width
                            height: 178
                            radius: 20
                            color: Qt.rgba(0.04, 0.05, 0.06, 0.48)
                            border.width: 1
                            border.color: root.palette.panelBorder

                            Column {
                                anchors.fill: parent
                                anchors.margins: 22
                                spacing: 12

                                Text {
                                    text: "Current Theme"
                                    color: root.palette.mutedText
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Text {
                                    text: root.palette.name
                                    color: root.palette.primaryText
                                    font.pixelSize: 28
                                    font.bold: true
                                }

                                Text {
                                    width: parent.width
                                    text: root.wallpaperPath.length > 0
                                        ? "Background rerolled from the shipped BSDRunner wallpaper set for this launch."
                                        : "Waiting for a background wallpaper from the BSDRunner theme library."
                                    color: root.palette.secondaryText
                                    font.pixelSize: 16
                                    wrapMode: Text.WordWrap
                                    lineHeight: 1.14
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 10

                            Text {
                                text: "Sessions"
                                color: root.palette.mutedText
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Repeater {
                                model: root.sessions

                                delegate: Rectangle {
                                    id: sessionCard

                                    required property var modelData
                                    readonly property bool active: root.selectedSession === modelData.label
                                    width: parent.width
                                    height: 64
                                    radius: 18
                                    color: sessionCard.active ? root.palette.cardHover : Qt.rgba(0.04, 0.05, 0.06, 0.38)
                                    border.width: 2
                                    border.color: sessionCard.active ? themeLoader.actionAccent("session") : root.palette.panelBorder

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 16
                                        spacing: 4

                                        Text {
                                            text: sessionCard.modelData.label
                                            color: sessionCard.active ? root.palette.accentStrong : root.palette.primaryText
                                            font.pixelSize: 18
                                            font.bold: true
                                        }

                                        Text {
                                            text: sessionCard.modelData.subtitle
                                            color: root.palette.secondaryText
                                            font.pixelSize: 13
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selectedSession = parent.modelData.label
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width - 470 - parent.spacing
                    height: parent.height
                    radius: 28
                    color: Qt.rgba(0.05, 0.06, 0.08, 0.80)
                    border.width: 2
                    border.color: root.palette.panelBorder

                    Column {
                        anchors.centerIn: parent
                        width: 520
                        spacing: 18

                        Text {
                            width: parent.width
                            text: "Sign In"
                            color: root.palette.primaryText
                            font.pixelSize: 40
                            font.bold: true
                        }

                        Text {
                            width: parent.width
                            text: "Typical BSDRunner login layout, ready for a future PAM-backed greeter service."
                            color: root.palette.secondaryText
                            font.pixelSize: 18
                            wrapMode: Text.WordWrap
                            lineHeight: 1.14
                        }

                        Column {
                            width: parent.width
                            spacing: 12

                            Text {
                                text: "Username"
                                color: root.palette.mutedText
                                font.pixelSize: 14
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
                                        if (text.length > 0)
                                            root.feedbackText = "UI only for now. Authentication and session startup backends are not wired yet."
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: parent.text.length === 0
                                        text: "Enter your username"
                                        color: root.palette.mutedText
                                        font.pixelSize: 18
                                    }
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 12

                            Text {
                                text: "Password"
                                color: root.palette.mutedText
                                font.pixelSize: 14
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
                                        if (text.length > 0)
                                            root.feedbackText = "UI only for now. Authentication and session startup backends are not wired yet."
                                    }

                                    Keys.onReturnPressed: root.requestLogin()

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: parent.text.length === 0
                                        text: "Enter your password"
                                        color: root.palette.mutedText
                                        font.pixelSize: 18
                                    }
                                }
                            }
                        }

                        Rectangle {
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
                }
            }
        }
    }
}
