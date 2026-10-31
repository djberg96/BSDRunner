pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

ShellRoot {
    id: root

    ThemeLoader {
        id: themeLoader
    }

    readonly property var palette: themeLoader.palette
    readonly property string activeTheme: themeLoader.activeTheme
    readonly property string backendPath: {
        var configured = String(Quickshell.env("BSDRUNNER_GREETER_BACKEND") || "")
        return configured.length > 0
            ? configured
            : "/usr/local/libexec/bsdrunner-greetd-greeter"
    }
    readonly property bool busy: loginInProgress && !awaitingResponse
    property string wallpaperPath: String(Quickshell.env("BSDRUNNER_GREETER_WALLPAPER") || "")
    property bool backendReady: false
    property bool loginInProgress: false
    property bool awaitingResponse: false
    property bool promptIsSecret: true
    property string pendingInitialResponse: ""
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

    function sendBackend(message) {
        backendProcess.write(JSON.stringify(message) + "\n")
    }

    function resetLogin() {
        loginInProgress = false
        awaitingResponse = false
        promptIsSecret = true
        pendingInitialResponse = ""
        passwordText = ""
    }

    function submitAuthResponse(response) {
        awaitingResponse = false
        passwordText = ""
        sendBackend({ "type": "auth_response", "response": response })
    }

    function handleBackendLine(line) {
        var event
        try {
            event = JSON.parse(line)
        } catch (error) {
            feedbackTone = "error"
            feedbackTitle = "Greeter Protocol Error"
            feedbackText = String(error)
            resetLogin()
            return
        }

        if (event.type === "ready") {
            backendReady = true
            return
        }

        if (event.type === "auth_message") {
            if (event.message_type === "secret" && pendingInitialResponse.length > 0) {
                var response = pendingInitialResponse
                pendingInitialResponse = ""
                submitAuthResponse(response)
                return
            }

            awaitingResponse = true
            promptIsSecret = event.message_type === "secret"
            feedbackTone = "info"
            feedbackTitle = "Authentication Required"
            feedbackText = String(event.message || "Enter the requested response.")
            passwordInput.forceActiveFocus()
            return
        }

        if (event.type === "notice") {
            feedbackTone = event.level === "error" ? "warning" : "info"
            feedbackTitle = event.level === "error" ? "Authentication Notice" : "Signing In"
            feedbackText = String(event.message || "")
            return
        }

        if (event.type === "starting_session") {
            awaitingResponse = false
            feedbackTone = "info"
            feedbackTitle = "Launching " + selectedSession
            feedbackText = "Credentials accepted. greetd is starting the selected session."
            return
        }

        if (event.type === "session_started") {
            Qt.quit()
            return
        }

        if (event.type === "canceled") {
            resetLogin()
            feedbackTone = "info"
            feedbackTitle = "Sign In Canceled"
            feedbackText = "The pending greetd session was canceled."
            return
        }

        if (event.type === "error") {
            resetLogin()
            feedbackTone = "error"
            feedbackTitle = event.kind === "authentication"
                ? "Authentication Failed"
                : "Greeter Backend Error"
            feedbackText = String(event.message || "The sign-in request failed.")
        }
    }

    function requestLogin() {
        var requestedUser = usernameText.trim()

        if (awaitingResponse) {
            if (passwordText.length === 0)
                return
            submitAuthResponse(passwordText)
            return
        }

        if (!backendReady) {
            feedbackTone = "error"
            feedbackTitle = "Greeter Backend Not Ready"
            feedbackText = "The native greetd bridge has not connected yet."
            return
        }

        if (usernameText.trim().length === 0) {
            feedbackTone = "error"
            feedbackTitle = "Missing Credentials"
            feedbackText = "Enter a username before trying to sign in."
            return
        }

        pendingInitialResponse = passwordText
        passwordText = ""
        loginInProgress = true
        sessionMenuOpen = false
        feedbackTone = "info"
        feedbackTitle = "Authenticating " + requestedUser
        feedbackText = "Beginning a new session through greetd."
        sendBackend({
            "type": "login",
            "username": requestedUser,
            "session": selectedSession === "Terminal" ? "terminal" : "bsdrunner"
        })
    }

    Connections {
        target: Quickshell

        function onLastWindowClosed() {
            if (root.loginInProgress)
                root.sendBackend({ "type": "cancel" })
            Qt.quit()
        }
    }

    Process {
        id: backendProcess
        property var controller: root

        command: [root.backendPath]
        running: true
        stdinEnabled: true

        stdout: SplitParser {
            onRead: function(data) {
                backendProcess.controller.handleBackendLine(data)
            }
        }

        stderr: SplitParser {
            onRead: function(data) {
                backendProcess.controller.feedbackTone = "error"
                backendProcess.controller.feedbackTitle = "Greeter Backend Error"
                backendProcess.controller.feedbackText = data
            }
        }

        onExited: function(exitCode) {
            backendProcess.controller.backendReady = false
            backendProcess.controller.resetLogin()
            backendProcess.controller.feedbackTone = "error"
            backendProcess.controller.feedbackTitle = "Greeter Backend Stopped"
            backendProcess.controller.feedbackText = "The native greetd bridge exited with status " + exitCode + "."
        }
    }

    PanelWindow {
        id: window

        visible: true
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "bsdrunner-greeter"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        anchors {
            top: true
            right: true
            bottom: true
            left: true
        }

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
                                    enabled: !root.loginInProgress
                                    focus: true
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
                                    echoMode: root.promptIsSecret ? TextInput.Password : TextInput.Normal
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
                                        text: root.awaitingResponse ? "Response" : "Password"
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
                                    width: parent.width
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
                                        text: root.awaitingResponse ? "Continue" : "Sign In"
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
                                        onClicked: root.requestLogin()
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
                                        enabled: !root.loginInProgress
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
                                                    enabled: !root.loginInProgress
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
