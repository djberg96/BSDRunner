pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import Qt.labs.folderlistmodel

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
    readonly property string wallpaperPath: themeLoader.selectedTheme.length > 0
        ? (wallpaperFiles.count > 0 ? String(wallpaperFiles.get(0, "filePath")) : "")
        : String(Quickshell.env("BSDRUNNER_GREETER_WALLPAPER") || "")
    property bool backendReady: false
    property bool loginInProgress: false
    property bool awaitingResponse: false
    property bool promptIsSecret: true
    property string pendingInitialResponse: ""
    property string usernameText: ""
    property string passwordText: ""
    property string selectedSession: "BSDRunner"
    property bool sessionMenuOpen: false
    property bool themeMenuOpen: false
    property bool motdOpen: false
    property string feedbackTone: "info"
    property string feedbackTitle: ""
    property string feedbackText: ""

    FolderListModel {
        id: themeFolders
        folder: "file://" + themeLoader.greeterDir + "/themes"
        showDirs: true
        showFiles: false
        showDotAndDotDot: false
        sortField: FolderListModel.Name
    }

    FolderListModel {
        id: wallpaperFiles
        folder: "file://" + themeLoader.greeterDir + "/themes/" + themeLoader.activeTheme + "/wallpapers"
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.JPG", "*.JPEG", "*.PNG", "*.WEBP"]
        showDirs: false
        showFiles: true
        sortField: FolderListModel.Name
    }

    FileView {
        id: motdFile
        path: "/etc/motd"
        blockLoading: true
        watchChanges: true
        onFileChanged: this.reload()
    }

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
        themeMenuOpen = false
        feedbackTone = "info"
        feedbackTitle = "Authenticating " + requestedUser
        feedbackText = "Beginning a new session through greetd."
        sendBackend({
            "type": "login",
            "username": requestedUser,
            "session": selectedSession === "Terminal" ? "terminal" : "bsdrunner",
            "theme": themeLoader.selectedTheme.length > 0 ? themeLoader.selectedTheme : null
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
                color: root.palette.frameBackground
                opacity: 0.38
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: Qt.rgba(root.palette.frameBackground.r,
                                       root.palette.frameBackground.g,
                                       root.palette.frameBackground.b,
                                       0.72)
                    }
                    GradientStop {
                        position: 0.55
                        color: Qt.rgba(root.palette.frameBackground.r,
                                       root.palette.frameBackground.g,
                                       root.palette.frameBackground.b,
                                       0.24)
                    }
                    GradientStop {
                        position: 1.0
                        color: Qt.rgba(root.palette.frameBackground.r,
                                       root.palette.frameBackground.g,
                                       root.palette.frameBackground.b,
                                       0.80)
                    }
                }
            }

            Item {
                anchors.fill: parent
                anchors.margins: 54

                Rectangle {
                    id: signInFrame
                    width: 780
                    height: 424
                    anchors.centerIn: parent
                    radius: 28
                    color: Qt.rgba(root.palette.panelBackground.r,
                                   root.palette.panelBackground.g,
                                   root.palette.panelBackground.b,
                                   0.78)
                    border.width: 2
                    border.color: root.palette.frameBorder

                    Item {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 424

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
                            id: loginColumn
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
                                id: usernameField
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
                                        motdButton.forceActiveFocus()
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
                                id: passwordField
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
                                        sessionButton.forceActiveFocus()
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
                                id: signInRow
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
                            id: rightControls
                            width: 220
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            x: parent.width - width - 34

                            Text {
                                anchors.bottom: sessionButton.top
                                anchors.bottomMargin: 10
                                text: "SESSION"
                                color: root.palette.mutedText
                                font.pixelSize: 12
                                font.bold: true
                                font.letterSpacing: 1.2
                            }

                            Button {
                                id: sessionButton
                                width: parent.width
                                height: usernameField.height
                                y: loginColumn.y + usernameField.y
                                text: root.selectedSession + (root.sessionMenuOpen ? "   ˄" : "   ˅")
                                enabled: !root.loginInProgress
                                onClicked: { root.themeMenuOpen = false; root.sessionMenuOpen = !root.sessionMenuOpen }
                                Keys.onDownPressed: {
                                    root.themeMenuOpen = false
                                    root.sessionMenuOpen = true
                                    if (sessionOptions.count > 0) sessionOptions.itemAt(0).forceActiveFocus()
                                }
                                Keys.onBacktabPressed: function(event) { passwordInput.forceActiveFocus(); event.accepted = true }
                                Keys.onTabPressed: function(event) { themeButton.forceActiveFocus(); event.accepted = true }
                                background: Rectangle {
                                    radius: 18
                                    color: sessionButton.hovered || sessionButton.visualFocus ? root.palette.cardHover : root.palette.cardBackground
                                    border.width: 1
                                    border.color: root.sessionMenuOpen || sessionButton.visualFocus ? root.palette.accentStrong : root.palette.panelBorder
                                }
                                contentItem: Text {
                                    text: sessionButton.text
                                    color: root.palette.primaryText
                                    font.pixelSize: 16
                                    font.bold: true
                                    leftPadding: 18
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            Button {
                                id: themeButton
                                width: parent.width
                                height: passwordField.height
                                y: loginColumn.y + passwordField.y
                                text: "Theme: " + root.palette.name + (root.themeMenuOpen ? "  ˄" : "  ˅")
                                enabled: !root.loginInProgress
                                onClicked: { root.sessionMenuOpen = false; root.themeMenuOpen = !root.themeMenuOpen }
                                Keys.onDownPressed: {
                                    root.sessionMenuOpen = false
                                    root.themeMenuOpen = true
                                    if (themeOptions.count > 0) themeOptions.itemAt(0).forceActiveFocus()
                                }
                                Keys.onBacktabPressed: function(event) { sessionButton.forceActiveFocus(); event.accepted = true }
                                Keys.onTabPressed: function(event) { motdButton.forceActiveFocus(); event.accepted = true }
                                background: Rectangle {
                                    radius: 18
                                    color: themeButton.hovered || themeButton.visualFocus ? root.palette.cardHover : root.palette.cardBackground
                                    border.width: 1
                                    border.color: root.themeMenuOpen || themeButton.visualFocus ? root.palette.accentStrong : root.palette.panelBorder
                                }
                                contentItem: Text {
                                    text: themeButton.text
                                    color: root.palette.primaryText
                                    font.pixelSize: 15
                                    font.bold: true
                                    leftPadding: 18
                                    rightPadding: 10
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            Button {
                                id: motdButton
                                width: parent.width
                                height: signInButton.height
                                y: loginColumn.y + signInRow.y
                                text: "MOTD"
                                enabled: !root.loginInProgress
                                onClicked: {
                                    root.sessionMenuOpen = false
                                    root.themeMenuOpen = false
                                    root.motdOpen = true
                                    motdDialog.forceActiveFocus()
                                }
                                Keys.onBacktabPressed: function(event) { themeButton.forceActiveFocus(); event.accepted = true }
                                Keys.onTabPressed: function(event) { usernameInput.forceActiveFocus(); event.accepted = true }
                                background: Rectangle {
                                    radius: 18
                                    color: motdButton.hovered || motdButton.visualFocus ? root.palette.cardHover : root.palette.cardBackground
                                    border.width: 1
                                    border.color: motdButton.visualFocus ? root.palette.accentStrong : root.palette.panelBorder
                                }
                                contentItem: Text {
                                    text: motdButton.text
                                    color: root.palette.primaryText
                                    font.pixelSize: 16
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            Rectangle {
                                z: 10
                                visible: root.sessionMenuOpen
                                anchors.top: sessionButton.bottom
                                anchors.topMargin: 4
                                width: parent.width
                                height: sessionMenuColumn.implicitHeight + 16
                                radius: 18
                                color: root.palette.cardBackground
                                border.width: 1
                                border.color: root.palette.panelBorder
                                Column {
                                    id: sessionMenuColumn
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 6
                                    Repeater {
                                        id: sessionOptions
                                        model: root.sessions
                                        delegate: Button {
                                            id: sessionOption
                                            required property var modelData
                                            required property int index
                                            width: sessionMenuColumn.width
                                            height: 44
                                            text: modelData.label
                                            Keys.onEscapePressed: { root.sessionMenuOpen = false; sessionButton.forceActiveFocus() }
                                            Keys.onDownPressed: sessionOptions.itemAt((index + 1) % sessionOptions.count).forceActiveFocus()
                                            Keys.onUpPressed: sessionOptions.itemAt((index + sessionOptions.count - 1) % sessionOptions.count).forceActiveFocus()
                                            onClicked: {
                                                root.selectedSession = modelData.label
                                                root.sessionMenuOpen = false
                                                sessionButton.forceActiveFocus()
                                            }
                                            background: Rectangle {
                                                radius: 10
                                                color: sessionOption.hovered || sessionOption.visualFocus || root.selectedSession === sessionOption.modelData.label ? root.palette.cardHover : "transparent"
                                            }
                                            contentItem: Text {
                                                text: sessionOption.text
                                                color: root.palette.primaryText
                                                font.pixelSize: 15
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                z: 10
                                visible: root.themeMenuOpen
                                anchors.top: themeButton.bottom
                                anchors.topMargin: 4
                                width: parent.width
                                height: themeMenuColumn.implicitHeight + 16
                                radius: 18
                                color: root.palette.cardBackground
                                border.width: 1
                                border.color: root.palette.panelBorder
                                Column {
                                    id: themeMenuColumn
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 4
                                    Repeater {
                                        id: themeOptions
                                        model: themeFolders
                                        delegate: Button {
                                            id: themeOption
                                            required property string fileName
                                            required property int index
                                            Keys.onEscapePressed: { root.themeMenuOpen = false; themeButton.forceActiveFocus() }
                                            Keys.onDownPressed: themeOptions.itemAt((index + 1) % themeOptions.count).forceActiveFocus()
                                            Keys.onUpPressed: themeOptions.itemAt((index + themeOptions.count - 1) % themeOptions.count).forceActiveFocus()
                                            width: themeMenuColumn.width
                                            height: 40
                                            text: fileName.split("-").map(function(part) {
                                                return part.charAt(0).toUpperCase() + part.slice(1)
                                            }).join("-")
                                            onClicked: {
                                                themeLoader.selectedTheme = fileName
                                                root.themeMenuOpen = false
                                                themeButton.forceActiveFocus()
                                            }
                                            background: Rectangle {
                                                radius: 10
                                                color: themeOption.hovered || themeOption.visualFocus || root.activeTheme === themeOption.fileName ? root.palette.cardHover : "transparent"
                                            }
                                            contentItem: Text {
                                                text: themeOption.text
                                                color: root.palette.primaryText
                                                font.pixelSize: 15
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            FocusScope {
                id: motdDialog
                anchors.fill: parent
                visible: root.motdOpen
                z: 20
                Keys.onEscapePressed: {
                    root.motdOpen = false
                    motdButton.forceActiveFocus()
                }

                Rectangle {
                    anchors.fill: parent
                    color: "#bb000000"
                    MouseArea { anchors.fill: parent }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(780, parent.width - 80)
                    height: Math.min(560, parent.height - 80)
                    radius: 24
                    color: root.palette.panelBackground
                    border.width: 2
                    border.color: root.palette.frameBorder

                    Text {
                        id: motdHeading
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: 28
                        text: "Message of the Day"
                        color: root.palette.primaryText
                        font.pixelSize: 25
                        font.bold: true
                    }

                    Flickable {
                        id: motdScroll
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: motdHeading.bottom
                        anchors.bottom: closeMotd.top
                        anchors.margins: 28
                        clip: true
                        contentWidth: width
                        contentHeight: motdText.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        Text {
                            id: motdText
                            width: motdScroll.width - 16
                            text: motdFile.text().trim() || "No system message is available."
                            textFormat: Text.PlainText
                            color: root.palette.primaryText
                            font.pixelSize: 17
                            wrapMode: Text.Wrap
                        }
                    }

                    Button {
                        id: closeMotd
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 24
                        width: 150
                        height: 48
                        text: "Close"
                        focus: true
                        Keys.onTabPressed: function(event) { event.accepted = true }
                        Keys.onBacktabPressed: function(event) { event.accepted = true }
                        onClicked: { root.motdOpen = false; motdButton.forceActiveFocus() }
                        background: Rectangle {
                            radius: 14
                            color: closeMotd.hovered || closeMotd.visualFocus ? root.palette.cardHover : root.palette.cardBackground
                            border.width: 1
                            border.color: root.palette.accentStrong
                        }
                        contentItem: Text {
                            text: closeMotd.text
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
