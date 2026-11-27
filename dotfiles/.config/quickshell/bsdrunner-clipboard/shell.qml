pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls

ShellRoot {
    id: root
    ThemeLoader { id: themeLoader }
    readonly property var colors: themeLoader.palette
    property var entries: []
    property string searchText: ""
    property string statusText: "Loading clipboard history…"
    readonly property var filteredEntries: entries.filter(function(entry) {
        return entry.preview.toLowerCase().indexOf(root.searchText.toLowerCase()) !== -1
    })
    function refresh() {
        if (!snapshot.running && !actionProcess.running) snapshot.running = true
    }
    function runAction(action, item) {
        if (actionProcess.running || snapshot.running) return
        actionProcess.actionName = action
        var command = ["sh", themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-clipboard-backend.sh", action]
        if (item !== undefined) command.push(String(item))
        actionProcess.command = command
        actionProcess.running = true
    }
    IpcHandler { target: "clipboard"; function close(): void { Qt.quit() } }
    Process {
        id: snapshot
        command: ["sh", themeLoader.homeDir + "/.config/bsdrunner/scripts/bsdrunner-clipboard-backend.sh", "list"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var result = JSON.parse(text)
                    if (!Array.isArray(result)) throw new Error("Invalid response")
                    root.entries = result
                    root.statusText = result.length ? "" : "No clipboard history yet. Copy something to get started."
                    historyList.currentIndex = result.length ? 0 : -1
                } catch (error) {
                    root.entries = []
                    root.statusText = "Could not read clipboard history. Check that Cliphist is installed."
                }
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.entries = []
                root.statusText = "Could not read clipboard history. Check that Cliphist is installed."
            }
        }
    }
    Process {
        id: actionProcess
        property string actionName: ""
        onExited: function(exitCode) {
            if (exitCode !== 0) root.statusText = "Clipboard action failed."
            else if (actionName === "copy") Qt.quit()
            else refreshAfterAction.restart()
        }
    }
    Timer { id: refreshAfterAction; interval: 100; repeat: false; onTriggered: root.refresh() }
    Component.onCompleted: refresh()
    Connections { target: Quickshell; function onLastWindowClosed() { Qt.quit() } }
    FloatingWindow {
        id: window
        visible: true
        title: "BSDRunner Clipboard"
        minimumSize: Qt.size(700, 600)
        maximumSize: Qt.size(700, 600)
        color: "transparent"
        Rectangle {
            anchors.fill: parent; radius: 24
            color: root.colors.frameBackground; border.width: 2; border.color: root.colors.frameBorder
            Rectangle {
                anchors.fill: parent; anchors.margins: 14; radius: 18
                color: root.colors.panelBackground; border.color: root.colors.panelBorder
                Column {
                    anchors.fill: parent; anchors.margins: 22; spacing: 11
                    Row {
                        width: parent.width; height: 44; spacing: 12
                        Text { width: parent.width - closeButton.width - 12; height: parent.height; verticalAlignment: Text.AlignVCenter; text: "Clipboard History"; color: root.colors.primaryText; font.pixelSize: 25; font.bold: true }
                        Rectangle {
                            id: closeButton
                            width: 42; height: 42; radius: 11
                            color: closeMouse.containsMouse ? root.colors.cardHover : root.colors.cardBackground; border.color: root.colors.frameBorder
                            Text { anchors.centerIn: parent; text: "×"; color: root.colors.primaryText; font.pixelSize: 22 }
                            MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Qt.quit() }
                        }
                    }
                    Text { width: parent.width; text: "Select an item to copy it, then paste as usual."; color: root.colors.mutedText; font.pixelSize: 12 }
                    Rectangle {
                        width: parent.width; height: 40; radius: 10
                        color: root.colors.cardBackground; border.color: search.activeFocus ? root.colors.accent : root.colors.frameBorder
                        Text { anchors.fill: parent; anchors.leftMargin: 12; verticalAlignment: Text.AlignVCenter; visible: search.text.length === 0; text: "Search clipboard history"; color: root.colors.mutedText; font.pixelSize: 12 }
                        TextInput {
                            id: search
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter; color: root.colors.primaryText; selectionColor: root.colors.accent
                            font.pixelSize: 13; focus: true; clip: true
                            onTextChanged: { root.searchText = text; historyList.currentIndex = root.filteredEntries.length ? 0 : -1 }
                            Keys.onEscapePressed: Qt.quit()
                            Keys.onDownPressed: historyList.incrementCurrentIndex()
                            Keys.onUpPressed: historyList.decrementCurrentIndex()
                            Keys.onReturnPressed: if (historyList.currentIndex >= 0 && historyList.currentIndex < root.filteredEntries.length) root.runAction("copy", root.filteredEntries[historyList.currentIndex].id)
                        }
                    }
                    Rectangle {
                        width: parent.width; height: 312; radius: 12
                        color: root.colors.cardBackground; border.color: root.colors.frameBorder
                        Text {
                            anchors.centerIn: parent; width: parent.width - 32; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                            visible: root.statusText !== "" || (root.entries.length > 0 && root.filteredEntries.length === 0)
                            text: root.statusText || "No matching clipboard items."
                            color: root.colors.mutedText; font.pixelSize: 13
                        }
                        ListView {
                            id: historyList
                            anchors.fill: parent; anchors.margins: 8; clip: true; spacing: 5
                            model: root.filteredEntries
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                            delegate: Rectangle {
                                id: row
                                required property var modelData
                                required property int index
                                width: ListView.view.width; height: 48; radius: 8
                                color: rowMouse.containsMouse || ListView.isCurrentItem ? root.colors.cardHover : root.colors.panelBackground
                                Text {
                                    x: 12; width: parent.width - 62; height: parent.height
                                    verticalAlignment: Text.AlignVCenter; text: row.modelData.preview; textFormat: Text.PlainText
                                    color: root.colors.primaryText; font.pixelSize: 12; elide: Text.ElideRight
                                }
                                MouseArea {
                                    id: rowMouse; x: 0; width: parent.width - 48; height: parent.height
                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.runAction("copy", row.modelData.id)
                                }
                                Rectangle {
                                    anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                                    width: 36; height: 34; radius: 8
                                    color: deleteMouse.containsMouse ? root.colors.cardBackground : "transparent"
                                    Text { anchors.centerIn: parent; text: "×"; color: root.colors.mutedText; font.pixelSize: 18 }
                                    MouseArea { id: deleteMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.runAction("delete", row.modelData.id) }
                                }
                            }
                        }
                    }
                    Row {
                        width: parent.width; height: 36; spacing: 12
                        Rectangle {
                            width: 125; height: 34; radius: 9
                            color: clearMouse.containsMouse ? root.colors.cardHover : root.colors.cardBackground; border.color: root.colors.frameBorder
                            Text { anchors.centerIn: parent; text: "Clear history"; color: root.colors.primaryText; font.pixelSize: 12 }
                            MouseArea { id: clearMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.runAction("clear") }
                        }
                        Text { height: 34; verticalAlignment: Text.AlignVCenter; text: root.filteredEntries.length + " items"; color: root.colors.mutedText; font.pixelSize: 11 }
                    }
                    Text {
                        width: parent.width; wrapMode: Text.WordWrap
                        text: "History stays in the private session runtime. Apps may not mark copied secrets as sensitive."
                        color: root.colors.mutedText; font.pixelSize: 11
                    }
                }
            }
        }
    }
}
