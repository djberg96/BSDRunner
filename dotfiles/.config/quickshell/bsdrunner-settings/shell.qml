pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

ShellRoot {
    id: root

    ThemeLoader {
        id: themeLoader
    }

    readonly property var palette: themeLoader.palette
    property string searchText: ""
    readonly property var categories: [
        {
            "action": "appearance",
            "icon": "LOOK",
            "title": "Appearance",
            "detail": "Themes, colors, and wallpaper style",
            "keywords": "theme colors wallpaper desktop look",
            "tone": "accent"
        },
        {
            "action": "network",
            "icon": "NET",
            "title": "Network",
            "detail": "Wi-Fi, connections, and recovery",
            "keywords": "wireless wifi internet access point",
            "tone": "accent"
        },
        {
            "action": "power",
            "icon": "LOCK",
            "title": "Power & Lock",
            "detail": "Idle timeout and session locking",
            "keywords": "power screen lock screensaver idle hyprlock",
            "tone": "success"
        },
        {
            "action": "firewall",
            "icon": "PF",
            "title": "Firewall",
            "detail": "Protection profiles, rules, and logs",
            "keywords": "pf firewall security ports tarpit",
            "tone": "warning"
        },
        {
            "action": "dns",
            "icon": "DNS",
            "title": "Encrypted DNS",
            "detail": "Resolvers, forwarding, and cache",
            "keywords": "dns encrypted unbound resolver privacy",
            "tone": "accent"
        },
        {
            "action": "software",
            "icon": "PKG",
            "title": "Software",
            "detail": "Install, remove, and update packages",
            "keywords": "package manager apps update upgrade pkg",
            "tone": "accent"
        },
        {
            "action": "zfs",
            "icon": "ZFS",
            "title": "Storage & ZFS",
            "detail": "Pools, datasets, and snapshots",
            "keywords": "storage disk pool dataset snapshot zfs",
            "tone": "success"
        },
        {
            "action": "jails",
            "icon": "JLS",
            "title": "Jails",
            "detail": "FreeBSD isolation and services",
            "keywords": "jail bastille container network service",
            "tone": "warning"
        },
        {
            "action": "time",
            "icon": "TIME",
            "title": "Date & Time",
            "detail": "Clock format and timezone behavior",
            "keywords": "clock date time timezone travel",
            "tone": "accent"
        },
        {
            "action": "battery",
            "icon": "BATT",
            "title": "Battery",
            "detail": "Charge status and alert threshold",
            "keywords": "battery charge laptop threshold power",
            "tone": "success"
        }
    ]
    readonly property var filteredCategories: filterCategories(searchText)

    function filterCategories(query) {
        var needle = String(query || "").trim().toLowerCase()
        if (needle.length === 0)
            return categories
        return categories.filter(function(category) {
            var haystack = category.title + " " + category.detail + " " + category.keywords
            return haystack.toLowerCase().indexOf(needle) !== -1
        })
    }

    function accentFor(tone) {
        switch (tone) {
        case "success": return palette.success
        case "warning": return palette.warning
        case "danger": return palette.danger
        default: return palette.accent
        }
    }

    function commandFor(action) {
        var scripts = themeLoader.homeDir + "/.config/bsdrunner/scripts/"
        var waybarScripts = themeLoader.homeDir + "/.config/waybar/scripts/"
        switch (action) {
        case "appearance": return ["sh", waybarScripts + "bsdrunner-theme-menu.sh"]
        case "network": return ["sh", scripts + "bsdrunner-network.sh"]
        case "power": return ["sh", scripts + "bsdrunner-power.sh"]
        case "firewall": return ["sh", scripts + "bsdrunner-pf.sh"]
        case "dns": return ["sh", scripts + "bsdrunner-dns.sh"]
        case "software": return ["sh", scripts + "bsdrunner-software.sh"]
        case "zfs": return ["sh", scripts + "bsdrunner-zfs.sh"]
        case "jails": return ["sh", scripts + "bsdrunner-jails.sh"]
        case "time": return ["sh", waybarScripts + "bsdrunner-clock.sh", "menu"]
        case "battery": return ["sh", scripts + "bsdrunner-battery-window.sh"]
        default: return []
        }
    }

    function openCategory(action) {
        var command = commandFor(action)
        if (command.length > 0)
            Quickshell.execDetached(command)
    }

    Connections {
        target: Quickshell

        function onLastWindowClosed() {
            Qt.quit()
        }
    }

    FloatingWindow {
        id: window

        visible: true
        title: "BSDRunner Settings"
        minimumSize: Qt.size(1000, 680)
        maximumSize: Qt.size(1000, 680)
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 24
            color: root.palette.frameBackground
            border.width: 2
            border.color: root.palette.frameBorder

            Rectangle {
                anchors.fill: parent
                anchors.margins: 14
                radius: 18
                color: root.palette.panelBackground
                border.width: 1
                border.color: root.palette.panelBorder

                Column {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 14

                    Row {
                        width: parent.width
                        height: 62
                        spacing: 12

                        Column {
                            width: parent.width - closeButton.width - 12
                            spacing: 3

                            Text {
                                text: "BSDRunner Settings"
                                color: root.palette.primaryText
                                font.pixelSize: 28
                                font.bold: true
                            }

                            Text {
                                text: "Configure your " + root.palette.name + " desktop"
                                color: root.palette.mutedText
                                font.pixelSize: 12
                            }
                        }

                        Rectangle {
                            id: closeButton

                            width: 44
                            height: 44
                            radius: 12
                            color: closeMouse.containsMouse ? root.palette.cardHover : root.palette.cardBackground
                            border.width: 1
                            border.color: root.palette.frameBorder

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                color: root.palette.primaryText
                                font.pixelSize: 24
                            }

                            MouseArea {
                                id: closeMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Qt.quit()
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 46
                        radius: 12
                        color: root.palette.cardBackground
                        border.width: searchInput.activeFocus ? 2 : 1
                        border.color: searchInput.activeFocus ? root.palette.accent : root.palette.frameBorder

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 8
                            spacing: 10

                            Text {
                                height: parent.height
                                verticalAlignment: Text.AlignVCenter
                                text: "⌕"
                                color: root.palette.accent
                                font.pixelSize: 22
                            }

                            Item {
                                width: parent.width - 74
                                height: parent.height

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: "Search settings"
                                    color: root.palette.mutedText
                                    font.pixelSize: 13
                                    visible: searchInput.text.length === 0
                                }

                                TextInput {
                                    id: searchInput

                                    anchors.fill: parent
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: root.palette.primaryText
                                    selectionColor: root.palette.accent
                                    selectedTextColor: root.palette.frameBackground
                                    font.pixelSize: 13
                                    focus: true
                                    clip: true
                                    onTextChanged: root.searchText = text
                                    Keys.onEscapePressed: Qt.quit()
                                }
                            }

                            Rectangle {
                                width: 32
                                height: 32
                                anchors.verticalCenter: parent.verticalCenter
                                radius: 9
                                visible: searchInput.text.length > 0
                                color: clearMouse.containsMouse ? root.palette.cardHover : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "×"
                                    color: root.palette.secondaryText
                                    font.pixelSize: 18
                                }

                                MouseArea {
                                    id: clearMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: searchInput.text = ""
                                }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 424

                        Grid {
                            id: settingsGrid

                            width: parent.width
                            columns: 4
                            rowSpacing: 12
                            columnSpacing: 12

                            Repeater {
                                model: root.filteredCategories

                                delegate: Rectangle {
                                    id: categoryCard

                                    required property var modelData
                                    readonly property color accent: root.accentFor(modelData.tone)

                                    width: (settingsGrid.width - settingsGrid.columnSpacing * 3) / 4
                                    height: 128
                                    radius: 15
                                    color: categoryMouse.containsMouse ? root.palette.cardHover : root.palette.cardBackground
                                    border.width: categoryMouse.containsMouse ? 2 : 1
                                    border.color: categoryMouse.containsMouse ? accent : root.palette.frameBorder

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 7

                                        Rectangle {
                                            width: 48
                                            height: 30
                                            radius: 9
                                            color: Qt.alpha(categoryCard.accent, 0.16)
                                            border.width: 1
                                            border.color: categoryCard.accent

                                            Text {
                                                anchors.centerIn: parent
                                                text: categoryCard.modelData.icon
                                                color: categoryCard.accent
                                                font.pixelSize: 10
                                                font.bold: true
                                            }
                                        }

                                        Text {
                                            width: parent.width
                                            text: categoryCard.modelData.title
                                            color: root.palette.primaryText
                                            font.pixelSize: 15
                                            font.bold: true
                                        }

                                        Text {
                                            width: parent.width
                                            text: categoryCard.modelData.detail
                                            color: root.palette.mutedText
                                            font.pixelSize: 11
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        id: categoryMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.openCategory(categoryCard.modelData.action)
                                    }
                                }
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 6
                            visible: root.filteredCategories.length === 0

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "No settings found"
                                color: root.palette.primaryText
                                font.pixelSize: 17
                                font.bold: true
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Try a different search term."
                                color: root.palette.mutedText
                                font.pixelSize: 12
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        height: 28

                        Text {
                            width: parent.width / 2
                            text: root.filteredCategories.length + " of " + root.categories.length + " categories"
                            color: root.palette.mutedText
                            font.pixelSize: 11
                        }

                        Text {
                            width: parent.width / 2
                            horizontalAlignment: Text.AlignRight
                            text: "Super+I opens Settings"
                            color: root.palette.mutedText
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }
}
