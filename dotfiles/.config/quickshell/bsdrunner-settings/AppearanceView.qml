pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls

Column {
    id: root
    required property var colors
    required property string homeDir
    signal back()
    property int brightness: 0
    property bool available: false
    property string statusText: "Reading brightness…"
    spacing: 18

    function refresh() {
        if (visible && !readProcess.running && !setProcess.running && !brightnessSlider.pressed)
            readProcess.running = true
    }
    function applyBrightness(value) {
        if (!available || setProcess.running) return
        brightness = Math.max(5, Math.min(100, Math.round(value)))
        statusText = "Applying brightness…"
        setProcess.command = ["sh", homeDir + "/.config/bsdrunner/scripts/bsdrunner-brightness.sh", "set", String(brightness)]
        setProcess.running = true
    }
    Process {
        id: readProcess
        command: ["sh", root.homeDir + "/.config/bsdrunner/scripts/bsdrunner-brightness.sh", "get"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var value = String(text).trim()
                if (/^\d+$/.test(value) && Number(value) <= 100) {
                    if (!brightnessSlider.pressed && !setProcess.running) {
                        root.brightness = Number(value)
                        root.available = true
                        root.statusText = "Use F5 and F6 or the slider to adjust the screen."
                    }
                } else if (!setProcess.running) {
                    root.available = false
                    root.statusText = "Brightness is unavailable on this display."
                }
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0 && !setProcess.running) {
                root.available = false
                root.statusText = "Could not read screen brightness."
            }
        }
    }
    Process {
        id: setProcess
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.statusText = "Could not change screen brightness."
                root.available = false
            } else {
                root.refresh()
            }
        }
    }
    Timer {
        interval: 2000; running: root.visible; repeat: true
        onTriggered: root.refresh()
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
        Text { height: 40; verticalAlignment: Text.AlignVCenter; text: "Appearance"; color: root.colors.primaryText; font.pixelSize: 24; font.bold: true }
    }
    Rectangle {
        width: parent.width; height: 145; radius: 15
        color: root.colors.cardBackground; border.color: root.colors.frameBorder
        Column {
            anchors.fill: parent; anchors.margins: 18; spacing: 10
            Text { text: "Theme"; color: root.colors.primaryText; font.pixelSize: 18; font.bold: true }
            Text { text: "Choose desktop colors and wallpaper."; color: root.colors.mutedText; font.pixelSize: 12 }
            Rectangle {
                width: 140; height: 38; radius: 10
                color: themeMouse.containsMouse ? root.colors.cardHover : root.colors.panelBackground
                border.color: root.colors.frameBorder
                Text { anchors.centerIn: parent; text: "Choose theme"; color: root.colors.primaryText; font.pixelSize: 13 }
                MouseArea {
                    id: themeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["sh", root.homeDir + "/.config/waybar/scripts/bsdrunner-theme-menu.sh"])
                }
            }
        }
    }
    Rectangle {
        width: parent.width; height: 190; radius: 15
        color: root.colors.cardBackground; border.color: root.colors.frameBorder
        Column {
            anchors.fill: parent; anchors.margins: 18; spacing: 10
            Row {
                width: parent.width; height: 27
                Text { width: parent.width - 80; text: "Screen brightness"; color: root.colors.primaryText; font.pixelSize: 18; font.bold: true }
                Text { width: 80; horizontalAlignment: Text.AlignRight; text: root.available ? root.brightness + "%" : "—"; color: root.colors.accent; font.pixelSize: 18; font.bold: true }
            }
            Slider {
                id: brightnessSlider
                width: parent.width; from: 5; to: 100; stepSize: 1; snapMode: Slider.SnapAlways
                enabled: root.available && !setProcess.running
                value: root.brightness
                onMoved: {
                    root.brightness = Math.round(value)
                    if (!pressed) root.applyBrightness(value)
                }
                onPressedChanged: if (!pressed && enabled && Math.round(value) !== 0) root.applyBrightness(value)
            }
            Text { width: parent.width; text: root.statusText; color: root.colors.mutedText; font.pixelSize: 12; wrapMode: Text.WordWrap }
        }
    }
}
