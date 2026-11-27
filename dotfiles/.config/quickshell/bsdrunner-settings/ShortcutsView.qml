pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

Column {
    id: root
    required property var colors
    required property string homeDir
    signal back()
    property var shortcuts: []
    property string statusText: ""
    spacing: 12

    function refresh() {
        if (!bindingsProcess.running) {
            shortcuts = []
            statusText = "Loading shortcuts…"
            bindingsProcess.running = true
        }
    }
    function keys(binding) {
        var mask = Number(binding.modmask || 0), result = []
        if (mask & 64) result.push("Super")
        if (mask & 4) result.push("Ctrl")
        if (mask & 8) result.push("Alt")
        if (mask & 1) result.push("Shift")
        if (mask & 2) result.push("Caps Lock")
        if (mask & 16) result.push("Mod2")
        if (mask & 32) result.push("Mod3")
        if (mask & 128) result.push("Mod5")
        result.push(binding.key || (binding.keycode ? "Keycode " + binding.keycode : "Unknown key"))
        return result.join(" + ")
    }
    function action(binding) {
        var result = binding.description || binding.dispatcher || "Unknown action"
        var luaDispatcher = /^HL\.Dispatcher\(([^)]+)\)$/.exec(result)
        if (luaDispatcher) {
            var names = { close: "Close window", drag: "Move window", exec_cmd: "Run command",
                exit: "Exit Hyprland", float: "Toggle floating", focus: "Change focus or workspace",
                layout: "Change layout", move: "Move window", pseudo: "Toggle pseudo tiling",
                resize: "Resize window", toggle_special: "Toggle special workspace" }
            result = names[luaDispatcher[1]] || luaDispatcher[1]
        }
        if (binding.arg && !binding.description && !luaDispatcher) result += " — " + binding.arg
        if (binding.submap) result += " (submap: " + binding.submap + ")"
        return result
    }
    Process {
        id: bindingsProcess
        command: ["hyprctl", "-j", "binds"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var result = JSON.parse(text)
                    if (!Array.isArray(result)) throw new Error("Invalid response")
                    root.shortcuts = result
                    root.statusText = result.length ? "" : "No shortcuts reported by Hyprland."
                } catch (error) {
                    root.shortcuts = []
                    root.statusText = "Could not read shortcuts from Hyprland."
                }
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.shortcuts = []
                root.statusText = "Could not read shortcuts. Is Hyprland running?"
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
        Text { height: 40; verticalAlignment: Text.AlignVCenter; text: "Keyboard Shortcuts"; color: root.colors.primaryText; font.pixelSize: 24; font.bold: true }
    }
    Text {
        width: parent.width
        text: "Active Hyprland bindings, including custom shortcuts. Lua bindings may show only the action type."
        color: root.colors.mutedText; font.pixelSize: 12; wrapMode: Text.WordWrap
    }
    Row {
        spacing: 10
        Repeater {
            model: [
                { label: "Refresh", path: "" },
                { label: "Edit Lua config", path: "/.config/hypr/hyprland.lua" },
                { label: "Edit legacy bindings", path: "/.config/hypr/conf/keybindings.conf" }
            ]
            delegate: Rectangle {
                id: button
                required property var modelData
                width: buttonLabel.implicitWidth + 28; height: 36; radius: 9
                color: buttonMouse.containsMouse ? root.colors.cardHover : root.colors.cardBackground
                border.color: root.colors.frameBorder
                Text { id: buttonLabel; anchors.centerIn: parent; text: button.modelData.label; color: root.colors.primaryText; font.pixelSize: 12 }
                MouseArea {
                    id: buttonMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (button.modelData.path === "") root.refresh()
                        else Quickshell.execDetached(["xdg-open", root.homeDir + button.modelData.path])
                    }
                }
            }
        }
    }
    Text {
        width: parent.width
        text: "Edit the config for your Hyprland version; save changes and reload Hyprland if needed."
        color: root.colors.mutedText; font.pixelSize: 11; wrapMode: Text.WordWrap
    }
    Rectangle {
        width: parent.width; height: 420; radius: 12
        color: root.colors.cardBackground; border.color: root.colors.frameBorder
        Text {
            anchors.centerIn: parent; visible: root.statusText !== ""
            text: root.statusText; color: root.colors.mutedText; font.pixelSize: 13
        }
        ListView {
            anchors.fill: parent; anchors.margins: 8; clip: true
            model: root.shortcuts
            delegate: Rectangle {
                id: bindingRow
                required property var modelData
                required property int index
                width: ListView.view.width
                height: Math.max(42, bindingAction.implicitHeight + 16)
                color: index % 2 ? Qt.alpha(root.colors.frameBorder, 0.15) : "transparent"
                Text {
                    x: 10; width: 240; anchors.verticalCenter: parent.verticalCenter
                    text: root.keys(bindingRow.modelData); color: root.colors.accent
                    font.pixelSize: 12; font.bold: true; elide: Text.ElideRight
                }
                Text {
                    id: bindingAction
                    x: 260; width: parent.width - 270; anchors.verticalCenter: parent.verticalCenter
                    text: root.action(bindingRow.modelData); color: root.colors.primaryText
                    font.pixelSize: 12; wrapMode: Text.WrapAnywhere
                }
            }
        }
    }
}
