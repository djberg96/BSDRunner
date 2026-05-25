pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "../bsdrunner-common" as BSDRunnerCommon

ShellRoot {
    id: root

    BSDRunnerCommon.ThemeLoader {
        id: themeLoader
    }

    readonly property var palette: themeLoader.palette
    readonly property string activeTheme: themeLoader.activeTheme
    property string currentView: "browse"
    property string searchQuery: ""
    property string selectedPackageName: "firefox"
    property string statusMessage: "Prototype mode: package actions are mocked while we wire up the real pkg backend."
    property string statusTone: "info"
    readonly property var packageData: [
        {
            "name": "firefox",
            "version": "138.0.4,1",
            "installed": true,
            "update_available": false,
            "repo": "FreeBSD",
            "category": "Web",
            "comment": "Standards-focused desktop web browser",
            "description": "Mozilla Firefox with Wayland support, privacy features, and a familiar desktop workflow.",
            "website": "https://www.mozilla.org/firefox/",
            "license": "MPL-2.0",
            "size": "124 MB",
            "dependencies": ["gtk3", "dbus", "mesa-dri"]
        },
        {
            "name": "vscodium",
            "version": "1.101.14021",
            "installed": true,
            "update_available": true,
            "repo": "FreeBSD",
            "category": "Development",
            "comment": "Telemetry-free editor build based on VS Code",
            "description": "A familiar code editor option for users who want a polished UI without the upstream marketplace defaults.",
            "website": "https://vscodium.com/",
            "license": "MIT",
            "size": "331 MB",
            "dependencies": ["libsecret", "nss", "sqlite3"]
        },
        {
            "name": "wezterm",
            "version": "20240203",
            "installed": false,
            "update_available": false,
            "repo": "FreeBSD",
            "category": "Terminal",
            "comment": "GPU-accelerated terminal emulator and multiplexer",
            "description": "A modern terminal with tabs, panes, and strong remote workflows.",
            "website": "https://wezfurlong.org/wezterm/",
            "license": "MIT",
            "size": "18 MB",
            "dependencies": ["fontconfig", "libxkbcommon", "wayland"]
        },
        {
            "name": "obs-studio",
            "version": "31.0.3",
            "installed": false,
            "update_available": false,
            "repo": "FreeBSD",
            "category": "Media",
            "comment": "Live streaming and screen recording studio",
            "description": "Recording and broadcast tooling with scenes, audio routing, and plugin support.",
            "website": "https://obsproject.com/",
            "license": "GPL-2.0",
            "size": "59 MB",
            "dependencies": ["ffmpeg", "qt6-base", "speexdsp"]
        },
        {
            "name": "thunderbird",
            "version": "128.10.2",
            "installed": false,
            "update_available": false,
            "repo": "FreeBSD",
            "category": "Communication",
            "comment": "Email, calendar, and feed reader",
            "description": "A full-featured desktop mail client with calendar integration and account profiles.",
            "website": "https://www.thunderbird.net/",
            "license": "MPL-2.0",
            "size": "103 MB",
            "dependencies": ["gtk3", "icu", "sqlite3"]
        },
        {
            "name": "gitui",
            "version": "0.26.3",
            "installed": true,
            "update_available": false,
            "repo": "FreeBSD",
            "category": "Development",
            "comment": "Fast terminal UI for Git",
            "description": "A keyboard-friendly Git interface that fits well with the BSDRunner workflow.",
            "website": "https://github.com/extrawurst/gitui",
            "license": "MIT",
            "size": "4 MB",
            "dependencies": ["git"]
        },
        {
            "name": "kdenlive",
            "version": "24.12.3",
            "installed": false,
            "update_available": false,
            "repo": "FreeBSD",
            "category": "Media",
            "comment": "Non-linear video editor",
            "description": "A feature-rich editing suite for projects that need more than simple trimming.",
            "website": "https://kdenlive.org/",
            "license": "GPL-3.0",
            "size": "192 MB",
            "dependencies": ["mlt7", "qt6-multimedia", "frei0r"]
        },
        {
            "name": "neovim",
            "version": "0.11.1",
            "installed": true,
            "update_available": true,
            "repo": "FreeBSD",
            "category": "Development",
            "comment": "Extensible Vim-based text editor",
            "description": "Fast terminal editor with Lua configuration, LSP support, and broad plugin ecosystem.",
            "website": "https://neovim.io/",
            "license": "Apache-2.0",
            "size": "9 MB",
            "dependencies": ["libtermkey", "tree-sitter", "unibilium"]
        }
    ]
    readonly property var visiblePackages: filterPackages(currentView, searchQuery)
    readonly property var selectedPackage: findPackage(selectedPackageName)

    function normalize(value) {
        return (value || "").toLowerCase()
    }

    function matchesView(pkg, view) {
        if (view === "installed")
            return pkg.installed
        if (view === "updates")
            return pkg.update_available
        return true
    }

    function filterPackages(view, query) {
        var results = []
        var needle = normalize(query)

        for (var i = 0; i < packageData.length; i += 1) {
            var pkg = packageData[i]
            if (!matchesView(pkg, view))
                continue

            if (needle.length > 0) {
                var haystack = normalize(pkg.name + " " + pkg.comment + " " + pkg.category)
                if (haystack.indexOf(needle) === -1)
                    continue
            }

            results.push(pkg)
        }

        return results
    }

    function findPackage(name) {
        for (var i = 0; i < packageData.length; i += 1) {
            if (packageData[i].name === name)
                return packageData[i]
        }

        return null
    }

    function packageInList(name, list) {
        for (var i = 0; i < list.length; i += 1) {
            if (list[i].name === name)
                return true
        }

        return false
    }

    function viewTitle() {
        switch (currentView) {
        case "installed":
            return "Installed"
        case "updates":
            return "Updates"
        default:
            return "Browse"
        }
    }

    function viewSubtitle() {
        switch (currentView) {
        case "installed":
            return "Inspect the software that is already part of this BSDRunner machine."
        case "updates":
            return "Review the packages that would be refreshed in the next maintenance pass."
        default:
            return "Explore curated package metadata before we wire in the live pkg backend."
        }
    }

    function installedCount() {
        var count = 0
        for (var i = 0; i < packageData.length; i += 1) {
            if (packageData[i].installed)
                count += 1
        }
        return count
    }

    function updateCount() {
        var count = 0
        for (var i = 0; i < packageData.length; i += 1) {
            if (packageData[i].update_available)
                count += 1
        }
        return count
    }

    function triggerMockAction(action, pkgName) {
        var suffix = pkgName ? " for " + pkgName : ""
        statusTone = "warning"
        statusMessage = "Prototype only: " + action + suffix + " is not wired to pkg yet."
    }

    onVisiblePackagesChanged: {
        if (visiblePackages.length === 0) {
            selectedPackageName = ""
        } else if (!packageInList(selectedPackageName, visiblePackages)) {
            selectedPackageName = visiblePackages[0].name
        }
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
        title: "BSDRunner Software"
        minimumSize: Qt.size(1260, 780)
        maximumSize: Qt.size(1260, 780)
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 28
            color: root.palette.frameBackground
            border.width: 2
            border.color: root.palette.frameBorder

            Rectangle {
                anchors.fill: parent
                anchors.margins: 18
                radius: 22
                color: root.palette.panelBackground
                border.width: 1
                border.color: root.palette.panelBorder

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 126
                    radius: 22
                    color: root.palette.cardBackground
                    opacity: 0.82

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 220
                        radius: 22
                        color: root.palette.accent
                        opacity: 0.12
                    }
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 4
                    radius: 2
                    color: root.palette.accent
                    opacity: 0.95
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 26
                    spacing: 18

                    Rectangle {
                        width: 244
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        radius: 20
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.panelBorder

                        Column {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 20

                            Column {
                                spacing: 8

                                Text {
                                    text: root.palette.eyebrow
                                    color: root.palette.accent
                                    font.pixelSize: 17
                                    font.bold: true
                                }

                                Text {
                                    text: "Software"
                                    color: root.palette.primaryText
                                    font.pixelSize: 34
                                    font.bold: true
                                }

                                Text {
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    text: "A themed FreeBSD package surface designed for BSDRunner."
                                    color: root.palette.secondaryText
                                    font.pixelSize: 14
                                }
                            }

                            Column {
                                spacing: 10

                                Repeater {
                                    model: [
                                        {
                                            "id": "browse",
                                            "label": "Browse",
                                            "count": root.packageData.length,
                                            "accent": root.palette.accent
                                        },
                                        {
                                            "id": "installed",
                                            "label": "Installed",
                                            "count": root.installedCount(),
                                            "accent": root.palette.success
                                        },
                                        {
                                            "id": "updates",
                                            "label": "Updates",
                                            "count": root.updateCount(),
                                            "accent": root.palette.warning
                                        }
                                    ]

                                    delegate: Rectangle {
                                        id: navCard

                                        required property var modelData
                                        readonly property bool active: root.currentView === modelData.id

                                        width: 204
                                        height: 66
                                        radius: 16
                                        color: active ? root.palette.cardHover : root.palette.panelBackground
                                        border.width: 2
                                        border.color: active ? modelData.accent : root.palette.frameBorder

                                        Row {
                                            anchors.fill: parent
                                            anchors.margins: 14
                                            spacing: 12

                                            Rectangle {
                                                width: 38
                                                height: 38
                                                radius: 12
                                                color: modelData.accent
                                                opacity: active ? 0.22 : 0.14

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.count
                                                    color: modelData.accent
                                                    font.pixelSize: 14
                                                    font.bold: true
                                                }
                                            }

                                            Column {
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 2

                                                Text {
                                                    text: navCard.modelData.label
                                                    color: root.palette.primaryText
                                                    font.pixelSize: 17
                                                    font.bold: true
                                                }

                                                Text {
                                                    text: active ? "Current view" : "Switch view"
                                                    color: root.palette.mutedText
                                                    font.pixelSize: 12
                                                }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor

                                            onEntered: parent.color = root.palette.cardHover
                                            onExited: parent.color = parent.active ? root.palette.cardHover : root.palette.panelBackground
                                            onClicked: root.currentView = parent.modelData.id
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 156
                                radius: 18
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.frameBorder

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 8

                                    Text {
                                        text: "Current Theme"
                                        color: root.palette.mutedText
                                        font.pixelSize: 12
                                        font.bold: true
                                    }

                                    Text {
                                        text: root.palette.name
                                        color: root.palette.accentStrong
                                        font.pixelSize: 24
                                        font.bold: true
                                    }

                                    Text {
                                        width: parent.width
                                        wrapMode: Text.WordWrap
                                        text: "The final build will read live pkg data, then hand installs and upgrades off to mdo-backed actions."
                                        color: root.palette.secondaryText
                                        font.pixelSize: 13
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        width: 566
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        spacing: 16

                        Column {
                            spacing: 10

                            Text {
                                text: root.viewTitle()
                                color: root.palette.primaryText
                                font.pixelSize: 34
                                font.bold: true
                            }

                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: root.viewSubtitle()
                                color: root.palette.secondaryText
                                font.pixelSize: 15
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 60
                            radius: 18
                            color: root.palette.cardBackground
                            border.width: 1
                            border.color: root.palette.panelBorder

                            TextInput {
                                id: searchInput
                                anchors.fill: parent
                                anchors.margins: 18
                                color: root.palette.primaryText
                                selectionColor: root.palette.accent
                                selectedTextColor: root.palette.frameBackground
                                font.pixelSize: 16
                                clip: true
                                text: root.searchQuery

                                onTextChanged: root.searchQuery = text

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: parent.text.length === 0
                                    text: "Search packages, comments, or categories"
                                    color: root.palette.mutedText
                                    font.pixelSize: 16
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 68
                            radius: 16
                            color: root.statusTone === "warning" ? root.palette.warning : root.palette.accent
                            opacity: 0.18
                            border.width: 1
                            border.color: root.statusTone === "warning" ? root.palette.warning : root.palette.accent

                            Text {
                                anchors.fill: parent
                                anchors.margins: 16
                                verticalAlignment: Text.AlignVCenter
                                wrapMode: Text.WordWrap
                                text: root.statusMessage
                                color: root.palette.primaryText
                                font.pixelSize: 14
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: parent.parent.height - 188
                            radius: 20
                            color: root.palette.cardBackground
                            border.width: 1
                            border.color: root.palette.panelBorder

                            Item {
                                anchors.fill: parent
                                anchors.margins: 16

                                Column {
                                    id: emptyState
                                    anchors.centerIn: parent
                                    width: 280
                                    spacing: 8
                                    visible: root.visiblePackages.length === 0

                                    Text {
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        text: "No packages match this view."
                                        color: root.palette.primaryText
                                        font.pixelSize: 22
                                        font.bold: true
                                    }

                                    Text {
                                        width: parent.width
                                        wrapMode: Text.WordWrap
                                        horizontalAlignment: Text.AlignHCenter
                                        text: "Try clearing the search box or switch to another package view."
                                        color: root.palette.secondaryText
                                        font.pixelSize: 14
                                    }
                                }

                                Flickable {
                                    anchors.fill: parent
                                    contentWidth: width
                                    contentHeight: packageColumn.height
                                    clip: true
                                    visible: root.visiblePackages.length > 0

                                    Column {
                                        id: packageColumn
                                        width: parent.width
                                        spacing: 10

                                        Repeater {
                                            model: root.visiblePackages

                                            delegate: Rectangle {
                                                required property var modelData
                                                readonly property bool active: root.selectedPackageName === modelData.name

                                                width: packageColumn.width
                                                height: 102
                                                radius: 18
                                                color: active ? root.palette.cardHover : root.palette.panelBackground
                                                border.width: 1
                                                border.color: active ? root.palette.accent : root.palette.frameBorder

                                                Column {
                                                    anchors.fill: parent
                                                    anchors.margins: 16
                                                    spacing: 8

                                                    Row {
                                                        width: parent.width
                                                        spacing: 10

                                                        Text {
                                                            text: packageCard.modelData.name
                                                            color: root.palette.primaryText
                                                            font.pixelSize: 20
                                                            font.bold: true
                                                        }

                                                        Rectangle {
                                                            width: 80
                                                            height: 24
                                                            radius: 12
                                                            color: packageCard.modelData.installed ? root.palette.success : root.palette.accent
                                                            opacity: 0.16

                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: packageCard.modelData.installed ? "Installed" : "Available"
                                                                color: packageCard.modelData.installed ? root.palette.success : root.palette.accentStrong
                                                                font.pixelSize: 12
                                                                font.bold: true
                                                            }
                                                        }

                                                        Rectangle {
                                                            visible: packageCard.modelData.update_available
                                                            width: 72
                                                            height: 24
                                                            radius: 12
                                                            color: root.palette.warning
                                                            opacity: 0.16

                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: "Update"
                                                                color: root.palette.warning
                                                                font.pixelSize: 12
                                                                font.bold: true
                                                            }
                                                        }
                                                    }

                                                    Text {
                                                        width: parent.width
                                                        wrapMode: Text.WordWrap
                                                        text: packageCard.modelData.comment
                                                        color: root.palette.secondaryText
                                                        font.pixelSize: 14
                                                    }

                                                    Row {
                                                        spacing: 14

                                                        Text {
                                                            text: packageCard.modelData.category
                                                            color: root.palette.accent
                                                            font.pixelSize: 12
                                                            font.bold: true
                                                        }

                                                        Text {
                                                            text: packageCard.modelData.version
                                                            color: root.palette.mutedText
                                                            font.pixelSize: 12
                                                        }

                                                        Text {
                                                            text: packageCard.modelData.repo
                                                            color: root.palette.mutedText
                                                            font.pixelSize: 12
                                                        }
                                                    }
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor

                                                    onEntered: parent.color = root.palette.cardHover
                                                    onExited: parent.color = parent.active ? root.palette.cardHover : root.palette.panelBackground
                                                    onClicked: root.selectedPackageName = parent.modelData.name
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 364
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        radius: 20
                        color: root.palette.cardBackground
                        border.width: 1
                        border.color: root.palette.panelBorder

                        Column {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 16

                            Text {
                                text: root.selectedPackage ? root.selectedPackage.name : "No package selected"
                                color: root.palette.primaryText
                                font.pixelSize: 30
                                font.bold: true
                            }

                            Text {
                                visible: root.selectedPackage !== null
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: root.selectedPackage ? root.selectedPackage.description : ""
                                color: root.palette.secondaryText
                                font.pixelSize: 14
                            }

                            Rectangle {
                                visible: root.selectedPackage !== null
                                width: parent.width
                                height: 170
                                radius: 18
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.frameBorder

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 10

                                    Repeater {
                                        model: root.selectedPackage ? [
                                            {
                                                "label": "Version",
                                                "value": root.selectedPackage.version
                                            },
                                            {
                                                "label": "Repository",
                                                "value": root.selectedPackage.repo
                                            },
                                            {
                                                "label": "License",
                                                "value": root.selectedPackage.license
                                            },
                                            {
                                                "label": "Installed Size",
                                                "value": root.selectedPackage.size
                                            }
                                        ] : []

                                            delegate: Row {
                                                id: detailRow

                                                required property var modelData
                                                spacing: 12

                                                Text {
                                                    width: 108
                                                    text: detailRow.modelData.label
                                                    color: root.palette.mutedText
                                                    font.pixelSize: 12
                                                    font.bold: true
                                            }

                                                Text {
                                                    width: 180
                                                    wrapMode: Text.WordWrap
                                                    text: detailRow.modelData.value
                                                    color: root.palette.primaryText
                                                    font.pixelSize: 13
                                                }
                                        }
                                    }
                                }
                            }

                            Column {
                                visible: root.selectedPackage !== null
                                spacing: 8

                                Text {
                                    text: "Dependencies"
                                    color: root.palette.secondaryText
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Flow {
                                    width: parent.width
                                    spacing: 8

                                    Repeater {
                                        model: root.selectedPackage ? root.selectedPackage.dependencies : []

                                        delegate: Rectangle {
                                            id: dependencyChip

                                            required property string modelData

                                            height: 28
                                            radius: 14
                                            color: root.palette.panelBackground
                                            border.width: 1
                                            border.color: root.palette.frameBorder

                                            Text {
                                                anchors.centerIn: parent
                                                text: dependencyChip.modelData
                                                color: root.palette.primaryText
                                                font.pixelSize: 12
                                            }

                                            width: textMetrics.width + 24

                                            TextMetrics {
                                                id: textMetrics
                                                text: dependencyChip.modelData
                                                font.pixelSize: 12
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                visible: root.selectedPackage !== null
                                width: parent.width
                                height: 112
                                radius: 18
                                color: root.palette.panelBackground
                                border.width: 1
                                border.color: root.palette.frameBorder

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 10

                                    Text {
                                        text: "Actions"
                                        color: root.palette.secondaryText
                                        font.pixelSize: 14
                                        font.bold: true
                                    }

                                    Row {
                                        spacing: 10

                                        Repeater {
                                            model: root.selectedPackage ? [
                                                {
                                                    "label": root.selectedPackage.installed ? "Reinstall" : "Install",
                                                    "tone": "accent"
                                                },
                                                {
                                                    "label": "Upgrade",
                                                    "tone": "warning"
                                                },
                                                {
                                                    "label": "Remove",
                                                    "tone": "danger"
                                                }
                                            ] : []

                                            delegate: Rectangle {
                                                id: actionButton

                                                required property var modelData
                                                readonly property color toneColor: modelData.tone === "danger"
                                                    ? root.palette.danger
                                                    : modelData.tone === "warning"
                                                        ? root.palette.warning
                                                        : root.palette.accent

                                                width: 96
                                                height: 36
                                                radius: 12
                                                color: toneColor
                                                opacity: 0.16
                                                border.width: 1
                                                border.color: toneColor

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: actionButton.modelData.label
                                                    color: parent.toneColor
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor

                                                    onEntered: parent.opacity = 0.24
                                                    onExited: parent.opacity = 0.16
                                                    onClicked: root.triggerMockAction(actionButton.modelData.label.toLowerCase(), root.selectedPackage.name)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: root.selectedPackage !== null
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: root.selectedPackage ? root.selectedPackage.website : ""
                                color: root.palette.accentStrong
                                font.pixelSize: 13
                            }
                        }
                    }
                }
            }
        }
    }
}
