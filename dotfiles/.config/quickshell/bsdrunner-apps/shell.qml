pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

ShellRoot {
    id: root

    ThemeLoader {
        id: themeLoader
    }

    readonly property var palette: themeLoader.palette
    property bool open: false
    property string pendingAction: ""
    property var apps: [
        {
            "action": "files",
            "icon": "FILE",
            "label": "Files",
            "detail": "Browse local folders",
            "tone": "files"
        },
        {
            "action": "software",
            "icon": "PKG",
            "label": "Package Manager",
            "detail": "Install and update software",
            "tone": "apps"
        },
        {
            "action": "firewall",
            "icon": "PF",
            "label": "Firewall",
            "detail": "Manage desktop protection",
            "tone": "warning"
        },
        {
            "action": "dns",
            "icon": "DNS",
            "label": "DNS Cache",
            "detail": "Manage local name lookups",
            "tone": "info"
        },
        {
            "action": "zfs",
            "icon": "ZFS",
            "label": "ZFS",
            "detail": "Snapshots and pool health",
            "tone": "storage"
        },
        {
            "action": "firefox",
            "icon": "WEB",
            "label": "Firefox",
            "detail": "Open the web browser",
            "tone": "browser"
        }
    ]

    function accentFor(tone) {
        switch (tone) {
        case "success":
            return palette.success
        case "warning":
            return palette.warning
        case "info":
            return palette.accent
        case "storage":
            return themeLoader.actionAccent("storage")
        case "browser":
            return themeLoader.actionAccent("browser")
        case "files":
            return themeLoader.actionAccent("files")
        default:
            return themeLoader.actionAccent("apps")
        }
    }

    function commandFor(action) {
        switch (action) {
        case "files":
            return [
                "sh",
                themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-files.sh"
            ]
        case "software":
            return [
                "sh",
                themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-software.sh"
            ]
        case "firewall":
            return [
                "sh",
                themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-pf.sh"
            ]
        case "dns":
            return [
                "sh",
                themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-dns.sh"
            ]
        case "zfs":
            return [
                "sh",
                themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-zfs.sh"
            ]
        case "firefox":
            return ["firefox"]
        default:
            return []
        }
    }

    function closeMenu() {
        open = false
        closeTimer.restart()
    }

    function launch(action) {
        pendingAction = action
        open = false
        launchTimer.restart()
    }

    Timer {
        id: openTimer

        interval: 24
        repeat: false
        onTriggered: root.open = true
    }

    Timer {
        id: closeTimer

        interval: 150
        repeat: false
        onTriggered: Qt.quit()
    }

    Timer {
        id: launchTimer

        interval: 150
        repeat: false
        onTriggered: {
            var command = root.commandFor(root.pendingAction)
            if (command.length > 0)
                Quickshell.execDetached(command)
            Qt.quit()
        }
    }

    Component.onCompleted: openTimer.restart()

    Connections {
        target: Quickshell

        function onLastWindowClosed() {
            Qt.quit()
        }
    }

    // Qt's linter does not understand Quickshell PanelWindow metadata here.
    // qmllint disable uncreatable-type unqualified unresolved-type missing-property
    PanelWindow {
        id: window

        visible: true
        implicitWidth: 330
        implicitHeight: 408
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            left: true
        }

        margins {
            top: 52
            left: 76
        }
        // qmllint enable uncreatable-type unqualified unresolved-type missing-property

        Item {
            anchors.fill: parent
            clip: true

            Rectangle {
                id: panel

                width: parent.width
                height: parent.height
                y: root.open ? 0 : -height - 8
                opacity: root.open ? 1.0 : 0.0
                radius: 8
                color: root.palette.frameBackground
                border.width: 1
                border.color: root.palette.frameBorder

                Behavior on y {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                    }
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    Row {
                        width: parent.width
                        height: 24

                        Text {
                            width: parent.width - closeButton.width
                            height: parent.height
                            text: "Apps"
                            color: root.palette.accent
                            font.pixelSize: 13
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                        }

                        Rectangle {
                            id: closeButton

                            width: 24
                            height: 24
                            radius: 6
                            color: closeMouse.containsMouse ? root.palette.cardHover : root.palette.cardBackground
                            border.width: 1
                            border.color: root.palette.panelBorder

                            Text {
                                anchors.centerIn: parent
                                text: "X"
                                color: root.palette.secondaryText
                                font.pixelSize: 10
                                font.bold: true
                            }

                            MouseArea {
                                id: closeMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.closeMenu()
                            }
                        }
                    }

                    Repeater {
                        model: root.apps

                        delegate: Rectangle {
                            id: appRow

                            required property var modelData
                            readonly property color accent: root.accentFor(modelData.tone)

                            width: parent.width
                            height: 52
                            radius: 8
                            color: appMouse.containsMouse ? root.palette.cardHover : root.palette.panelBackground
                            border.width: 1
                            border.color: appMouse.containsMouse ? accent : root.palette.frameBorder

                            Row {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 10

                                Rectangle {
                                    width: 40
                                    height: 36
                                    radius: 8
                                    color: Qt.alpha(appRow.accent, 0.18)
                                    border.width: 1
                                    border.color: appRow.accent

                                    Text {
                                        anchors.centerIn: parent
                                        text: appRow.modelData.icon
                                        color: appRow.accent
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                }

                                Column {
                                    width: parent.width - 50
                                    spacing: 1

                                    Text {
                                        width: parent.width
                                        text: appRow.modelData.label
                                        color: root.palette.primaryText
                                        font.pixelSize: 13
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        text: appRow.modelData.detail
                                        color: root.palette.mutedText
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            MouseArea {
                                id: appMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.launch(appRow.modelData.action)
                            }
                        }
                    }
                }
            }
        }
    }
}
