pragma ComponentBehavior: Bound

import Quickshell.Io
import QtQuick
import QtQuick.Controls

Column {
    id: root
    required property var colors
    required property string homeDir
    signal back()
    property var details: []
    property string statusText: ""
    spacing: 14

    function refresh() {
        if (!infoProcess.running) {
            details = []
            statusText = "Loading system information…"
            infoProcess.running = true
        }
    }
    Process {
        id: infoProcess
        command: ["sh", root.homeDir + "/.config/bsdrunner/scripts/bsdrunner-system-info.sh"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var result = JSON.parse(text)
                    if (!Array.isArray(result)) throw new Error("Invalid response")
                    root.details = result
                    root.statusText = result.length ? "" : "No system information is available."
                } catch (error) {
                    root.details = []
                    root.statusText = "Could not read system information."
                }
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.details = []
                root.statusText = "Could not read system information."
            }
        }
    }
    Row {
        width: parent.width; height: 48; spacing: 14
        Rectangle {
            width: 78; height: 40; radius: 10
            color: backMouse.containsMouse ? root.colors.cardHover : root.colors.cardBackground
            border.color: root.colors.frameBorder
            Text { anchors.centerIn: parent; text: "‹  Back"; color: root.colors.primaryText; font.pixelSize: 14 }
            MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.back() }
        }
        Text { height: 40; verticalAlignment: Text.AlignVCenter; text: "System Info"; color: root.colors.primaryText; font.pixelSize: 24; font.bold: true }
    }
    Row {
        width: parent.width; height: 38; spacing: 14
        Rectangle {
            width: 90; height: 36; radius: 9
            color: refreshMouse.containsMouse ? root.colors.cardHover : root.colors.cardBackground
            border.color: root.colors.frameBorder
            Text { anchors.centerIn: parent; text: "Refresh"; color: root.colors.primaryText; font.pixelSize: 12 }
            MouseArea { id: refreshMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.refresh() }
        }
        Text { height: 36; verticalAlignment: Text.AlignVCenter; text: "Hardware and software details for this computer"; color: root.colors.mutedText; font.pixelSize: 12 }
    }
    Rectangle {
        width: parent.width; height: 440; radius: 12
        color: root.colors.cardBackground; border.color: root.colors.frameBorder
        Text {
            anchors.centerIn: parent; visible: root.statusText !== ""
            text: root.statusText; color: root.colors.mutedText; font.pixelSize: 13
        }
        ListView {
            anchors.fill: parent; anchors.margins: 8; clip: true
            model: root.details
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            delegate: Rectangle {
                id: infoRow
                required property var modelData
                required property int index
                width: ListView.view.width
                height: Math.max(42, infoValue.implicitHeight + 18)
                color: index % 2 ? Qt.alpha(root.colors.frameBorder, 0.15) : "transparent"
                Text {
                    x: 10; width: 200; anchors.verticalCenter: parent.verticalCenter
                    text: infoRow.modelData.label; color: root.colors.accent
                    font.pixelSize: 12; font.bold: true; elide: Text.ElideRight
                }
                Text {
                    id: infoValue
                    x: 220; width: parent.width - 230; anchors.verticalCenter: parent.verticalCenter
                    text: infoRow.modelData.value; color: root.colors.primaryText
                    font.pixelSize: 12; wrapMode: Text.WrapAnywhere
                }
            }
        }
    }
}
