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
    readonly property string currentDesktopUser: String(Quickshell.env("USER") || "")
    readonly property bool realBackendEnabled: String(Quickshell.env("BSDRUNNER_GREETER_REAL_BACKEND") || "") === "1"
    readonly property bool busy: actionRunning || authRunning
    property string wallpaperPath: ""
    property string wallpaperStdoutText: ""
    property bool wallpaperExited: false
    property bool wallpaperStdoutFinished: false
    property var authCommand: []
    property string authStdoutText: ""
    property string authStderrText: ""
    property bool authExited: false
    property bool authStdoutFinished: false
    property bool authStderrFinished: false
    property bool authRunning: false
    property int authExitCode: -1
    property var actionCommand: []
    property string pendingActionId: ""
    property string actionStdoutText: ""
    property string actionStderrText: ""
    property bool actionExited: false
    property bool actionStdoutFinished: false
    property bool actionStderrFinished: false
    property bool actionRunning: false
    property int actionExitCode: -1
    property string usernameText: ""
    property string passwordText: ""
    property string selectedSession: "BSDRunner"
    property bool sessionMenuOpen: false
    property string pendingAuthenticatedUser: ""
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

    function maybeFinalizeAuth() {
        if (!authExited || !authStdoutFinished || !authStderrFinished)
            return

        authRunning = false

        var stdoutText = authStdoutText.trim()
        var stderrText = authStderrText.trim()
        var authenticatedUser = pendingAuthenticatedUser

        if (authExitCode === 0) {
            if (realBackendEnabled) {
                feedbackTone = "info"
                feedbackTitle = "Launching " + selectedSession
                feedbackText = stdoutText.length > 0
                    ? stdoutText
                    : "Credentials were accepted. Launching the selected session."
                pendingAuthenticatedUser = ""
                Qt.quit()
                return
            }

            if (authenticatedUser !== currentDesktopUser) {
                feedbackTone = "warning"
                feedbackTitle = "Credentials Verified"
                feedbackText = "Authentication succeeded, but this preview can only launch sessions for the current desktop user (" + currentDesktopUser + "). A true multi-user login still needs a display-manager backend."
                pendingAuthenticatedUser = ""
                return
            }

            feedbackTone = "info"
            feedbackTitle = "Launching " + selectedSession
            feedbackText = stdoutText.length > 0
                ? stdoutText
                : "Credentials were accepted. Launching the selected preview session."

            pendingActionId = "login"
            actionStdoutText = ""
            actionStderrText = ""
            actionExited = false
            actionStdoutFinished = false
            actionStderrFinished = false
            actionExitCode = -1
            actionCommand = [
                "sh",
                themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-greeter-action.sh",
                "login",
                selectedSession
            ]
            actionRunning = true
        } else {
            feedbackTone = "error"
            feedbackTitle = authExitCode === 127
                ? "Greeter Backend Missing"
                : authExitCode === 1 || authExitCode === 126
                    ? "Greeter Backend Not Available"
                    : authExitCode === 3
                        ? "Authentication Could Not Begin"
                        : authExitCode === 5
                            ? "Account Not Available"
                            : "Authentication Failed"
            feedbackText = stderrText.length > 0
                ? stderrText
                : stdoutText.length > 0
                    ? stdoutText
                    : "The supplied credentials were not accepted."
        }

        pendingAuthenticatedUser = ""
    }

    function maybeFinalizeAction() {
        if (!actionExited || !actionStdoutFinished || !actionStderrFinished)
            return

        actionRunning = false

        var stdoutText = actionStdoutText.trim()
        var stderrText = actionStderrText.trim()
        var finishedAction = pendingActionId

        if (actionExitCode === 0) {
            if (finishedAction === "login") {
                Qt.quit()
                return
            }

            feedbackTone = "info"
            feedbackTitle = finishedAction === "shutdown" ? "Shutdown Requested" : "Restart Requested"
            feedbackText = stdoutText.length > 0
                ? stdoutText
                : "If policy allows it, the system should begin that power action."
        } else {
            feedbackTone = "error"
            feedbackTitle = finishedAction === "login"
                ? "Could Not Launch Session"
                : finishedAction === "shutdown"
                    ? "Could Not Shut Down"
                    : finishedAction === "restart"
                        ? "Could Not Restart"
                        : "Action Failed"
            feedbackText = stderrText.length > 0
                ? stderrText
                : stdoutText.length > 0
                    ? stdoutText
                    : "The requested action failed."
        }

        pendingActionId = ""
    }

    function runAction(actionId) {
        if (busy)
            return

        sessionMenuOpen = false

        if (actionId === "login") {
            requestLogin()
            return
        }

        if (actionId === "shutdown") {
            feedbackTone = "warning"
            feedbackTitle = "Attempting Shutdown"
            feedbackText = "Requesting a system shutdown through the configured privilege helper."
        } else if (actionId === "restart") {
            feedbackTone = "warning"
            feedbackTitle = "Attempting Restart"
            feedbackText = "Requesting a system restart through the configured privilege helper."
        }

        pendingActionId = actionId
        actionStdoutText = ""
        actionStderrText = ""
        actionExited = false
        actionStdoutFinished = false
        actionStderrFinished = false
        actionExitCode = -1
        actionCommand = [
            "sh",
            themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-greeter-action.sh",
            actionId,
            selectedSession
        ]
        actionRunning = true
    }

    function requestLogin() {
        var requestedUser = usernameText.trim()

        if (usernameText.trim().length === 0 || passwordText.length === 0) {
            feedbackTone = "error"
            feedbackTitle = "Missing Credentials"
            feedbackText = "Enter both a username and a password before trying to sign in."
            return
        }

        pendingAuthenticatedUser = requestedUser
        feedbackTone = "info"
        feedbackTitle = "Authenticating " + requestedUser
        feedbackText = realBackendEnabled
            ? "Checking credentials and starting the selected session through the BSDRunner login backend."
            : "Checking credentials through the BSDRunner greeter backend."

        authStdoutText = ""
        authStderrText = ""
        authExited = false
        authStdoutFinished = false
        authStderrFinished = false
        authExitCode = -1
        authCommand = realBackendEnabled
            ? [
                "sh",
                themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-greeter-login.sh",
                requestedUser,
                selectedSession,
                "login"
            ]
            : [
                "sh",
                themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-greeter-auth.sh",
                requestedUser,
                "login"
            ]
        authRunning = true
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

    Process {
        id: authProcess
        property var controller: root

        command: root.authCommand
        running: root.authRunning
        stdinEnabled: true

        onStarted: {
            write(root.passwordText + "\n")
            root.passwordText = ""
        }

        stdout: StdioCollector {
            waitForEnd: true

            onStreamFinished: {
                authProcess.controller.authStdoutText = text
                authProcess.controller.authStdoutFinished = true
                authProcess.controller.maybeFinalizeAuth()
            }
        }

        stderr: StdioCollector {
            waitForEnd: true

            onStreamFinished: {
                authProcess.controller.authStderrText = text
                authProcess.controller.authStderrFinished = true
                authProcess.controller.maybeFinalizeAuth()
            }
        }

        onExited: function(exitCode, exitStatus) {
            authProcess.controller.authExitCode = exitCode
            authProcess.controller.authExited = true
            authProcess.controller.maybeFinalizeAuth()
        }
    }

    Process {
        id: actionProcess
        property var controller: root

        command: root.actionCommand
        running: root.actionRunning

        stdout: StdioCollector {
            waitForEnd: true

            onStreamFinished: {
                actionProcess.controller.actionStdoutText = text
                actionProcess.controller.actionStdoutFinished = true
                actionProcess.controller.maybeFinalizeAction()
            }
        }

        stderr: StdioCollector {
            waitForEnd: true

            onStreamFinished: {
                actionProcess.controller.actionStderrText = text
                actionProcess.controller.actionStderrFinished = true
                actionProcess.controller.maybeFinalizeAction()
            }
        }

        onExited: function(exitCode, exitStatus) {
            actionProcess.controller.actionExitCode = exitCode
            actionProcess.controller.actionExited = true
            actionProcess.controller.maybeFinalizeAction()
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
                    height: 424
                    anchors.centerIn: parent
                    radius: 28
                    color: Qt.rgba(0.04, 0.05, 0.06, 0.68)
                    border.width: 2
                    border.color: root.palette.frameBorder

                    Item {
                        anchors.fill: parent

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: 96
                            radius: 28
                            color: "transparent"
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.08) }
                                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
                            }
                        }

                        Column {
                            width: 460
                            x: 44
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 14

                            Text {
                                width: parent.width
                                text: "Sign In"
                                color: root.palette.primaryText
                                font.pixelSize: 34
                                font.bold: true
                                font.letterSpacing: 0.4
                            }

                            Rectangle {
                                width: parent.width
                                height: 62
                                radius: 18
                                color: root.palette.cardBackground
                                border.width: 1
                                border.color: usernameInput.activeFocus
                                    ? root.palette.accentStrong
                                    : root.palette.panelBorder

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        usernameInput.forceActiveFocus()
                                        usernameInput.cursorPosition = usernameInput.text.length
                                    }
                                }

                                TextInput {
                                    id: usernameInput
                                    anchors.fill: parent
                                    anchors.margins: 18
                                    color: root.palette.primaryText
                                    selectionColor: root.palette.accent
                                    selectedTextColor: root.palette.frameBackground
                                    font.pixelSize: 18
                                    text: root.usernameText
                                    enabled: !root.busy
                                    activeFocusOnTab: true

                                    Keys.onReturnPressed: passwordInput.forceActiveFocus()
                                    Keys.onTabPressed: function(event) {
                                        passwordInput.forceActiveFocus()
                                        event.accepted = true
                                    }
                                    Keys.onBacktabPressed: function(event) {
                                        passwordInput.forceActiveFocus()
                                        event.accepted = true
                                    }

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
                                        font.pixelSize: 17
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 62
                                radius: 18
                                color: root.palette.cardBackground
                                border.width: 1
                                border.color: passwordInput.activeFocus
                                    ? root.palette.accentStrong
                                    : root.palette.panelBorder

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        passwordInput.forceActiveFocus()
                                        passwordInput.cursorPosition = passwordInput.text.length
                                    }
                                }

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
                                    enabled: !root.busy
                                    activeFocusOnTab: true

                                    onTextChanged: {
                                        root.passwordText = text
                                        if (text.length > 0 && root.feedbackTone !== "error") {
                                            root.feedbackTitle = ""
                                            root.feedbackText = ""
                                        }
                                    }

                                    Keys.onReturnPressed: root.requestLogin()
                                    Keys.onTabPressed: function(event) {
                                        usernameInput.forceActiveFocus()
                                        event.accepted = true
                                    }
                                    Keys.onBacktabPressed: function(event) {
                                        usernameInput.forceActiveFocus()
                                        event.accepted = true
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: parent.text.length === 0
                                        text: "Password"
                                        color: root.palette.mutedText
                                        font.pixelSize: 17
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
                                height: 66

                                Rectangle {
                                    id: signInButton
                                    width: 240
                                    height: parent.height
                                    radius: 18
                                    color: Qt.rgba(themeLoader.actionAccent("login").r,
                                                   themeLoader.actionAccent("login").g,
                                                   themeLoader.actionAccent("login").b,
                                                   0.22)
                                    border.width: 2
                                    border.color: themeLoader.actionAccent("login")

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Sign In"
                                        color: root.palette.primaryText
                                        font.pixelSize: 18
                                        font.bold: true
                                        font.letterSpacing: 0.3
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: parent.color = Qt.rgba(themeLoader.actionAccent("login").r,
                                                                           themeLoader.actionAccent("login").g,
                                                                           themeLoader.actionAccent("login").b,
                                                                           0.30)
                                        onExited: parent.color = Qt.rgba(themeLoader.actionAccent("login").r,
                                                                          themeLoader.actionAccent("login").g,
                                                                          themeLoader.actionAccent("login").b,
                                                                          0.22)
                                        enabled: !root.busy
                                        onClicked: root.runAction("login")
                                    }
                                }

                                Row {
                                    width: parent.width - signInButton.width - parent.spacing
                                    height: parent.height
                                    spacing: 12

                                    Repeater {
                                        model: [
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
                                            width: (parent.width - 12) / 2
                                            height: parent.height
                                            radius: 16
                                            color: Qt.rgba(0.05, 0.06, 0.08, 0.34)
                                            border.width: 1
                                            border.color: modelData.accent

                                            Text {
                                                anchors.centerIn: parent
                                                text: parent.modelData.label
                                                color: parent.modelData.accent
                                                font.pixelSize: 15
                                                font.bold: true
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor

                                                onEntered: parent.color = Qt.rgba(0.10, 0.12, 0.14, 0.52)
                                                onExited: parent.color = Qt.rgba(0.05, 0.06, 0.08, 0.34)
                                                enabled: !root.busy
                                                onClicked: root.runAction(parent.modelData.id)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            width: 220
                            height: 300
                            x: parent.width - width - 34
                            y: 34

                            Column {
                                width: parent.width
                                spacing: 10

                                Text {
                                    text: "SESSION"
                                    color: root.palette.mutedText
                                    font.pixelSize: 12
                                    font.bold: true
                                    font.letterSpacing: 1.2
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 58
                                    radius: 18
                                    color: root.palette.cardBackground
                                    border.width: 1
                                    border.color: root.sessionMenuOpen
                                        ? root.palette.accentStrong
                                        : root.palette.panelBorder

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 18
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.selectedSession
                                        color: root.palette.primaryText
                                        font.pixelSize: 16
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
                                        enabled: !root.busy
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
                                                    enabled: !root.busy
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
}
