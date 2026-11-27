pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls

ShellRoot {
    id: root
    ThemeLoader { id: themeLoader }
    readonly property var colors: themeLoader.palette
    property var notifications: []
    property string statusText: "Loading notifications…"

    function refresh() {
        if (!snapshot.running) snapshot.running = true
    }
    IpcHandler {
        target: "notifications"
        function close(): void { Qt.quit() }
    }
    Process {
        id: snapshot
        command: ["sh", themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-notifications-backend.sh"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var result = JSON.parse(text)
                    if (!result || !Array.isArray(result.notifications)) throw new Error("Invalid response")
                    root.notifications = result.notifications
                    root.statusText = !result.ok ? String(result.message || "Could not load notifications.") :
                        (result.notifications.length ? "" : "No notifications yet.")
                } catch (error) {
                    root.notifications = []
                    root.statusText = "Could not load notifications."
                }
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.notifications = []
                root.statusText = "Could not load notifications."
            }
        }
    }
    Component.onCompleted: refresh()
    Timer { interval: 5000; running: true; repeat: true; onTriggered: root.refresh() }
    Connections {
        target: Quickshell
        function onLastWindowClosed() { Qt.quit() }
    }
    FloatingWindow {
        id: window
        visible: true
        title: "BSDRunner Notifications"
        minimumSize: Qt.size(620, 600)
        maximumSize: Qt.size(620, 600)
        color: "transparent"
        Rectangle {
            anchors.fill: parent; radius: 24
            color: root.colors.frameBackground; border.width: 2; border.color: root.colors.frameBorder
            Rectangle {
                anchors.fill: parent; anchors.margins: 14; radius: 18
                color: root.colors.panelBackground; border.color: root.colors.panelBorder
                Column {
                    anchors.fill: parent; anchors.margins: 22; spacing: 12
                    Row {
                        width: parent.width; height: 48; spacing: 12
                        Text {
                            width: parent.width - closeButton.width - 12; height: parent.height
                            verticalAlignment: Text.AlignVCenter; text: "Notifications"
                            color: root.colors.primaryText; font.pixelSize: 25; font.bold: true
                        }
                        Rectangle {
                            id: closeButton
                            width: 42; height: 42; radius: 11
                            color: closeMouse.containsMouse ? root.colors.cardHover : root.colors.cardBackground
                            border.color: root.colors.frameBorder
                            Text { anchors.centerIn: parent; text: "×"; color: root.colors.primaryText; font.pixelSize: 22 }
                            MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Qt.quit() }
                        }
                    }
                    Text {
                        width: parent.width; text: "Current and recent notifications from this session"
                        color: root.colors.mutedText; font.pixelSize: 12
                    }
                    Rectangle {
                        width: parent.width; height: 428; radius: 12
                        color: root.colors.cardBackground; border.color: root.colors.frameBorder
                        Text {
                            anchors.centerIn: parent; width: parent.width - 32
                            horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                            visible: root.statusText !== ""; text: root.statusText
                            color: root.colors.mutedText; font.pixelSize: 13
                        }
                        ListView {
                            anchors.fill: parent; anchors.margins: 8; clip: true; spacing: 6
                            model: root.notifications
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                            delegate: Rectangle {
                                id: notificationRow
                                required property var modelData
                                width: ListView.view.width
                                height: contents.implicitHeight + 24
                                radius: 9; color: root.colors.panelBackground
                                Column {
                                    id: contents
                                    anchors.left: parent.left; anchors.right: parent.right
                                    anchors.top: parent.top; anchors.margins: 12; spacing: 5
                                    Row {
                                        width: parent.width; height: 19
                                        Text {
                                            width: parent.width - stateText.width - 10
                                            text: String(notificationRow.modelData.app); textFormat: Text.PlainText
                                            color: root.colors.accent; font.pixelSize: 11; font.bold: true; elide: Text.ElideRight
                                        }
                                        Text { id: stateText; text: String(notificationRow.modelData.status); color: root.colors.mutedText; font.pixelSize: 10 }
                                    }
                                    Text {
                                        width: parent.width; visible: text.length > 0
                                        text: String(notificationRow.modelData.title); textFormat: Text.PlainText
                                        color: root.colors.primaryText; font.pixelSize: 14; font.bold: true; wrapMode: Text.WrapAnywhere
                                    }
                                    Text {
                                        width: parent.width; visible: text.length > 0
                                        text: String(notificationRow.modelData.body); textFormat: Text.PlainText
                                        color: root.colors.secondaryText; font.pixelSize: 12; wrapMode: Text.WrapAnywhere
                                    }
                                }
                            }
                        }
                    }
                    Text { text: "F9 closes this window on supported keyboards."; color: root.colors.mutedText; font.pixelSize: 11 }
                }
            }
        }
    }
}
